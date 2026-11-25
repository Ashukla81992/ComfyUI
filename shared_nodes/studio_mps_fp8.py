"""ComfyUI extension: make fp8 "scaled" checkpoints work on Apple MPS.

Problem (reproduced on M1 Pro, torch 2.8, ComfyUI 0.13, comfy-kitchen 0.2.35):
  KSamplerAdvanced -> TypeError: Trying to convert Float8_e4m3fn to the MPS backend
  but it does not have support for that dtype.
MPS can *store* fp8 tensors but cannot cast fp8 <-> fp16/fp32.  comfy-kitchen's
eager backend dequantizes with `x.to(fp16)` on the weight's device.

Fix: register MPS kernels for comfy_kitchen::dequantize_fp8 / quantize_fp8.
  * dequantize: bit-exact 256-entry lookup table on the GPU (every e4m3fn / e5m2
    value is exactly representable in fp16/fp32), so per-layer weight decode
    stays on the GPU.
  * quantize (only used when a LoRA is merged into an fp8 weight): scale/clamp on
    the GPU, do the final fp8 cast on CPU, move back.
Nothing changes on CUDA/CPU.  Shared by every pipeline: comfy_service.sh links it into custom_nodes/.
"""
import logging

import torch

NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}

_LUT = {}


def _lut(fp8_dtype, out_dtype, device):
    key = (fp8_dtype, out_dtype, str(device))
    t = _LUT.get(key)
    if t is None:
        t = torch.arange(256, dtype=torch.uint8).view(fp8_dtype).to(torch.float32).to(out_dtype).to(device)
        _LUT[key] = t
    return t


def _install():
    if not (hasattr(torch.backends, "mps") and torch.backends.mps.is_available()):
        return
    try:
        from comfy_kitchen.backends.eager import quantization as q
    except Exception as e:  # kitchen not installed -> nothing to patch
        logging.info("[studio_mps_fp8] comfy_kitchen not found (%s); skipping", e)
        return
    codes = q.DTYPE_CODE_TO_DTYPE

    def dequant_mps(x, scale, output_dtype_code):
        out = codes[output_dtype_code]
        if x.dtype not in (torch.float8_e4m3fn, torch.float8_e5m2):
            return x.to(out) * scale.to(out)
        idx = x.view(torch.uint8).to(torch.int32)
        return _lut(x.dtype, out, x.device)[idx] * scale.to(device=x.device, dtype=out)

    def quant_mps(x, scale, output_dtype_code):
        out = codes[output_dtype_code]
        lp_max = torch.finfo(out).max
        temp = x * (1.0 / scale).to(x.dtype)
        temp = torch.clamp(temp, -lp_max, lp_max)
        return temp.cpu().to(out).to(x.device)

    torch.library.register_kernel("comfy_kitchen::dequantize_fp8", "mps", dequant_mps)
    torch.library.register_kernel("comfy_kitchen::quantize_fp8", "mps", quant_mps)

    # LoRA merge into an fp8 weight re-quantizes with comfy.float.stochastic_rounding,
    # which writes fp8 via copy_ on the weight's device -> route MPS through CPU.
    try:
        import comfy.float as cf
        orig_sr = cf.stochastic_rounding
        if not getattr(orig_sr, "_studio_mps", False):
            def sr(value, dtype, seed=0):
                if value.device.type == "mps" and dtype in (torch.float8_e4m3fn, torch.float8_e5m2):
                    return orig_sr(value.to("cpu", torch.float32), dtype, seed=seed).to(value.device)
                return orig_sr(value, dtype, seed=seed)
            sr._studio_mps = True
            cf.stochastic_rounding = sr
    except Exception as e:
        logging.warning("[studio_mps_fp8] could not wrap comfy.float.stochastic_rounding: %s", e)
    logging.info("[studio_mps_fp8] MPS fp8 dequant/quant kernels registered")

    # ComfyUI forces VRAMState.SHARED on MPS and ignores --novram/--lowvram. In SHARED mode a
    # model is fully "loaded" and every LoRA-patched weight keeps an unpatched backup -> a 13 GB
    # Wan expert becomes ~26 GB on a 16 GB Mac (observed: 21 GB swap, no sampling progress).
    # Honour an explicit --novram/--lowvram: weights stay put, are cast per layer, and LoRAs are
    # applied on the fly (LowVramPatch) with no backup copy.
    try:
        import comfy.model_management as mm
        from comfy.cli_args import args
        want = mm.VRAMState.NO_VRAM if args.novram else mm.VRAMState.LOW_VRAM if args.lowvram else None
        if want is not None and mm.vram_state == mm.VRAMState.SHARED:
            mm.vram_state = want
            logging.info("[studio_mps_fp8] MPS vram state overridden: SHARED -> %s", want.name)

            # Small models (VAE ~0.25 GB) gain nothing from per-layer streaming but get much slower
            # (tiled Wan VAE decode: 124 s streamed). Load models under 2 GB normally.
            orig_load = mm.load_models_gpu
            if not getattr(orig_load, "_studio_mps", False):
                def load_models_gpu(models, *a, **kw):
                    try:
                        small = all(m.model_size() < 2 * 2**30 for m in models)
                    except Exception:
                        small = False
                    if not small:
                        return orig_load(models, *a, **kw)
                    prev = mm.vram_state
                    mm.vram_state = mm.VRAMState.SHARED
                    try:
                        return orig_load(models, *a, **kw)
                    finally:
                        mm.vram_state = prev
                load_models_gpu._studio_mps = True
                mm.load_models_gpu = load_models_gpu
    except Exception as e:
        logging.warning("[studio_mps_fp8] could not override vram state: %s", e)


_install()
