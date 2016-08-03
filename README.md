avs-scripts
===========
   * [eedi3_resize] (#eedi3_resize)
   * [HiAA] (#HiAA)
   * [LUtils] (#LUtils)
   * [MAA2] (#MAA2)


eedi3_resize
------------

eedi3 based resizing script that allows to resize to arbitrary resolutions while maintaining the correct image center and chroma location. ~~Shamelessly copy-pasted from~~ Based on mawen1250s nnedi3_resize16 v3.0. Can work both in 8-bit and 16-bit.

Script version: 0.11

Requirements:

   * AviSynth+ 
   * Dither v1.24.0
   * eedi3 v0.9.2 (Firesledge mod)
   * Contra-Sharpen mod v3.4
   * SmoothAdjust v2.90
   * Masktools 2.0a48tp7fix5
   * LUtils v0.11

Input Formats: Y8/YV12/YV16/YV24 (8-bit or 16-bit stacked)

Parameters:

   + [int] target_width, target_height (source width/height)
       *   Resolution to resize to. Arbitrary resolutions are realized with Dither resizers.
   + [float] src_left (0), src_top (0), src_width(source width), src_height (source height)
       *   Parameters for cropping before resizing
   + [string] kernel_d (Spline36)
       *   Dither resizing kernel used for downscaling
       *   This kernel will also be used when upscaling to arbitrary resolutions that are not exactly multiples of 2
   + [string] kernel_u (Spline64)
       *   Dither resizing kernel used for upscaling
   + [bool] noring (false)
       *   Use non-ringing algorithms for Dither resizers
       *   Enabling this is not recommended, because eedi3_resize will use eedi3 for upscaling edges, anyway
       *   Downscaling with non-ringing resizers may result in blurring and aliasing artifacts
   + [various] alpha (0.4), beta (0.2), gamma (15.0), nrad (3), mdis (20), hp (false), threads (0), vcheck(2), vthreshmul(1.0), vthresh2(4.0) splinesclip(true)
       *   Parameters passed to eedi3. Refer to the eedi3 docs for more information
       *   vthreshmul multiplies default vthresh0 and vthresh1 by specified amount
       *   splinesclip determines if a clip upscaled with deringed Spline36Resize is passed to eedi3 as sclip
   + [float] ratiothr (1.125)
       *   When the scaling ratio is below this threshold, eedi3_resize will only use Dither resizers instead of 
           the eedi3+Dither_resize16 combo
   + [float] sharp (0)
       *   Strength of contra-sharpening applied to the upscaled clip
       *   A value of 0 disabled sharpening, sensible values are around 50-100
   + [bool] mixed (true)
       *   By default, eedi3_resize uses eedi3 (8-bit) and Dither resizers (16-bit) for edge areas
       *   If this parameter is enabled, the script will only use 16-bit Dither resizers for scaling flat areas to increase precision
       *   Disable this if you want flat areas to be resized using eedi3+Dither_resize16
   + [float] thr (1.0), elast (1.5)
       *   Threshold and elasticity for merging eedi3 output into the clip upscaled with 16-bit Dither resizers
       *   Increase thr to take less pixels from the eedi3 upscaled clip
       *   Increase elast to increase blending between pixels from the eedi3 and Dither upscaled sclips for smoother transitions
   + [string] output (input colorspace)
       *   Output format/color space
       *   May be either one of the AviSynth internal colorspace or one of the Dither formats (RGB48Y, RGB48YV12)
   + [string] curve (linear)
       *   Setting this parameter to any of the following values enables resizing in linear light:
           *   "709", "601", "170", "240", "sRGB", "2020"
       *   refer to the Dither documentation (Dither_y_gamma_to_linear) for more information
   + [float] gcor (1.0)
       *   Gamma correction to be applied when converting to linear light
       *   Requires curve to be something else than "linear"
   + [string] matrix (resolution-based)
       *   Matrix used for YUV->RGB conversion
       *   Defaults to "709" for HD material, "601" for SD material
       *   Refer to the Dither docs (Dither_convert_yuv_to_rgb) for more information
   + [bool] tv_range (true)
       *   Indicates whether the input clip is in TV or PC (full) range
   + [bool] cplace (MPEG2)
       *   Placement of the chroma samples on 4:2:0 YUV formats
       *   Supported values are MPEG2 and MPEG1
   + [int] y (3), u (2), v (u)
       *   Processing options for y/u/v planes:
           *  -x..0 : All the pixels of the plane will be set to -x (disables processing)
           *      1 : Disables processing of the plane (plane will contain garbage)
           *      2 : Copies plane from the input clip (disables processing) 
           *      3 : Plane will processed
   + [bool] lsb_in (false), lsb_out (lsb_in)
       *   Tells the script whether the input/output clips are 16-bit stacked or 8 bit
   + [bool] lsb
       *   When enabled, processing will be done in high bitdepth for increased precision and smooth gradients (but at the cost of speed)
       *   When disabled, eedi3_resize will use 8-bit resizers instead of 16-bit resizers
       *   Setting either lsb_in or lsb_out to true will enable high-bitdepth processing by default
       *   High-bitdepth processing is always enabled for RGB output, regardless of what the lsb parameter is set to
   + [int] dither (6)
       * Dither mode for 16->8-bit coversion
       * Refer to the Dither docs (DitherPost) for more information on the various dithering modes
   + [clip] mclip (Undefined)
       *   mask clip to be used as prescreener for eedi3. Depending on the content, it usually results in a significant speed gain


HiAA
---

Antialiasing script that works both in 16-bit and 8-bit.
Supports multiple antialiasing and supersampling methods (sangnom2, eedi3, nnedi3, resize kernels), masking and sharpening.

Script version: 0.13
**WIP - everything subject to change without notice**

Requirements:

   * AviSynth+ r1555
   * Dither v1.24.0
   * eedi3 v0.9.2 (Firesledge mod)
   * eedi3_resize v0.11
   * nnedi3 v0.9.4
   * nnedi3_resize16 v3.1
   * Contra-Sharpen mod v3.4
   * SmoothAdjust v2.90
   * Masktools v2.0b1
   * LUtils v0.11
   * Resize8 v1.1
   * RgTools v0.91
   * tmaskcleaner v0.9
   * Sangnom2 v0.35
   * Soothe
   * aWarpSharp2
   * LSFmod 1.9 (and prerequisites)
   * MSharpen 0.9
   * Variableblur 0.5

Input Formats: 

   * Y8/YV12/YV16/YV24 (8-bit or 16-bit stacked)
   * RGB24/RGB32
   * RGB48Y/RGB48YV12
    
    
Parameters:

   + [string] aa (sangnom2)
       *   Antiaaliasing method.
       *   Currently supported:
           *   eedi3
           *   eedi3+sangnom2
           *   nnedi3
           *   sangnom2        
   + [string] ss (nnedi3)
       *   Supersampling method. Currently supported: all the AVS+/Dither resizing kernels, nnedi3
   + [float] ssf (1.0 for eedi3/eedi3+sangnom2; 2.0 for sangnom2)
       *   Supersampling factor. Increase this to combat artifacts or excessive blurring.
   + [val] preaa (false)
       *   Enables daa type pre-pass antialiasing, which uses nnedi3 to interpolate from the 2 source fields 
           and averages the 2 resulting frames. Causes significant blurring, so only use it on particularly
           bad sources where lines won't connect otherwise (e.g. due to bad Deinterlacing/IVTC)
       *   Will be run in both directions if set to true. Set it to "hor" or "ver" to only preaa in one direction
   + [bool] lsb_in (false), lsb_out (lsb_in)
       *   Tells the script whether the input clips are 16-bit stacked or 8 bit
       *   Setting either of these parameters to true will enable lsb processing (which results in a speed hit)
   + [int] y (3), u (2), v (u)
       *   Processing options for y/u/v planes:
           *  -x..0 : All the pixels of the plane will be set to -x (disables processing)
           *      1 : Disables processing of the plane (plane will contain garbage)
           *      2 : Copies plane from the input clip (disables processing) 
           *      3 : Plane will antialiased and masked
           *      4 : Plane will be antialiased and output as is (ignoring the mask)
   + [string] fmt_in (autodetect) / fmt_out (fmt_in)
       *   Allows you to specify the input and output colorspaces
       *   Specifying fmt_in is required for rgb48y and rgb48yv12
   + [int] dither (6)
       *   Dither mode for conversion from 16-bit to 8-bit (refer to dither docs for more information)
   + [float] ee_fac (2.0)
       *   Scaling factor for eedi3 interpolation.
       *   Using anything other than multiples of two will incur an additional performance hit
   + [various] ee_alpha, ee_beta, ee_gamma, ee_nrad, ee_mdis, ee_hp
       *   Eedi3 parameters (refer to eedi3 docs for more information)
   + [various] nn_nsize, nn_nns, nn_qual, nn_etype, nn_pscrn
       *   Nnedi3 parameters (refer to nnedi3 docs for more information)
   + [bool/string] sharp (false)
       *   Sharpening applied to the supersampled clip after antialiasing
       *   Can be True/False or one of the following methods:
           *    "csmod" : contra sharpening (Default if set to true)
           *    "lsfmod" : LSFmod with configurable defaults and strength
           *    "awarpsharp2" : aWarpSharp2 applied at supersampling resolution (ssf*ee_fac)
           *    "awarp4" : aWarpSharp2 applied at 4x source resolution 
           *    "msharpen" : MSharpen
   + [int] cs_strength (75)
       *   Contra sharpening strength
   + [val] cs_limit (true)
       *   Limits contra sharpening to either:
           *    "ss" : the supersampled (see ss) and preprocessed (see preaa) source clip
           *    "src" : the source clip, seperately supersample with the Spline36 kernel
       *   Enable this if you want the output to be no sharper than the source
       *   If set to true, "src" will be used if preaa is enabled, otherwise "ss"
           *    You might want to override this on terribly aliased sources in case
                the contra sharpening reintroduces some of the aliasing
   + [int] aw_thresh, aw_blur, aw_depth (4 for awarpsharp2; 2 for awarp4)
       *   Parameters passed to aWarpSharp2 (refer to awarpsharp2 docs for more information)
   + [various] lsf_strength (60), lsf_defaults (fast)
       *   Parameters passed to LSFmod (refer to LSFmod docs for more information)
   + [int] ms_strength (50), ms_threshold
       *   Parameters passed to MSharpen (refer to MSharpen docs for more information)
   + [string] kernel_d (Spline36)
       *   Kernel to use for downscaling back to the source resolution
   + [bool] noring (false)
       *   If enabled, a non-ringing kernel will be used for supersampling
       *   Doesn't apply to nnedi3 supersampling
   + [string] matrix (709 if input height >= 600, otherwise 601)
       *   Color matrix to be used for conversions between YUV and RGB
   + [bool] tv_range (true)
       *   Specifies the range of the pixel values of the input and output clips
   + [string] cplace (MPEG2)
       *   Chroma siting of the clip to be processed (refer to the Dither docs for more information)
   + [bool/string] mask (simple if no mclip is specified, otherwise false)
       *   Specifies whether or not the script should build an edge mask for masked antialiasing
       *   Can be either True/False or one of the following mask presets:
           *    simple: simple and fast mask, one for each plane
           *    simple-cmb: like simple, but uses a combined mask for all planes
           *    precise-cmb: cleaned mask that tries to skip small details
           *    lines: use this preset for a rather strict "line" mask that skips small details as well as larger detailed areas
       *   The mask is also used as a prescreener for eedi3 so using one will yield a considerable speedup
   + [clip] mclip (Undefined)
      *   Allows you to bring your own mask instead of relying on HiAA's internal masking
      *   The mask must be 8-bit YUV and of the same resolution as the source clip
      *   If you supply an Y8 mask, HiAA will automatically used its Y plane for masking all processed source planes
      *   For other color spaces the chroma subsampling must match that of the input clip (use YV24 for RGB input)
          and HiAA will mask all planes separatly
   + [int] mthr (30)
      *   Binarization threshold for the internal masking. 
      *   Decrease if the masking misses aliased edges, increase if the mask includes pristine details and flat areas
   + [bool] show (false)
      *   If enabled, visualizes the mask instead of running the antialiasing
      *   Useful for tweaking mask and mthr
   + [bool/int] sa_aa (true for aa methods that include sangnom, otherwise false) sa_aac (false)  
      *   Enables/Disables Sangnom2 based antialiasing on the luma and chroma channels
      *   Enabled if the supplied is an integer, which will be passed on as aa/aac parameters to Sangnom2 
   + [int] threads
      *   Number of threads to be used by eedi3/nnedi3/Sangnom2


LUtils
------

A collection of helper and wrapper functions meant to help script authors in handling common operations (especially 8/16-bit processing) and shortcomings of the avs scripting language without having to write the same boilerplate over and over again. 
Most of these functions require AviSynth+

Script version: 0.11

Function list:

   * Lu16To8
   * Lu8To16
   * LuBlankClip
   * LuConvCSP 
   * LuEdi
   * LUIsDefined
   * LuIsEq
   * LuIsFunction
   * LuIsHD
   * LuIsSameRes
   * LuLimitDif
   * LuLut
   * LuMatchCSP
   * LuMerge
   * LuMergePlanes
   * LUResize
   * LuRGB48YV12ToRGB48Y
   * LuSeparateColumns  
   * LuStackedNto16
   * LuSubstrAtIdx
   * LuSubstrCnt
   * LuPlanarToStacked


MAA2
----

Updated version of the MAA antialising script from AnimeIVTC. 
MAA2 uses tp7's SangNom2 and FTurn, which provide a nice speedup for SangNom-based antialiasing,
especially when only processing the luma plane.
The defaults of MAA2 match up with MAA, so you'll get identical output (save for the more accurate border region processing of SangNom2)
when using this script as a drop-in replacement.

MAA2 supports Y8, YV12 and YV24 input.

Script version: 0.41

Requirements:

   * AviSynth 2.6a4
   * SangNom2 0.3+
   * FTurn
   * Masktools 2.0a48
    
Parameters:

   + [int] mask (1)
       *   0: Disable masking
       *   1: Enable masking 
       *  -i: Enable masking with custom treshold (sensible values are between 0 and 30)
   + [bool] chroma (false)
       *   false: Don't process chroma channels (copy UV from the source clip if present)
       *   true: Process chroma channels
   + [float] ss (2.0)
       *   Supersampling factor (sensible values are between 2.0 and 4.0 for HD content)
   + [int] aa (48)
       *   Sangnom2 luma antialiasing strength
   + [int] aac (aa-8)
       *   Sangnom2 chroma antialiasing strength
   + [int] threads (4)
       *   Number of threads used by every Sangnom2 instance
   + [int] show (0)
       *   0: Don't overlay mask
       *   1: Overlay mask only
       *   2: Overlay mask and run antialiasing on the luma plane
