##################################################
###                                            ###
###              GrainFactoryLite+             ###
###                                            ###
###      by 06_taro - astrataro@gmail.com      ###
###                                            ###
###            v1.3 - 15 March 2015            ###
###                                            ###
##################################################
###
### Luma adaptive grain generating filter with stacked 16-bit input/output support
###
### Based on Didée's GrainFactory3 script, processing in 16-bit precision, and some commonly unused parameters removed
### The strength is reduced for general use
### 
###
### +-------------+
### |  CHANGELOG  |
### +-------------+
###
### v1.3 - 15 March 2015
###      - Changes by Reel.Deal
###      - Added support for Y8, YV16, and YV24
###      - Updated requirements to current status
###      - Remove redundancies and other minor cosmetics
###
### v1.2 - 06 April 2012
###      - Added support for generating f3kdb based grain ( set negative value for g*str to use f3kdb based grain )
###      - Minor fix on grainLayer adddiff usage
###
### v1.1-2 - 27 March 2012
###        - Adjusted merge16_8 usage to latest version of dither package
###
### v1.1-1 - 14 March 2012
###        - Minor fixes
###
### v1.1 - 13 March 2012
###      - Added chroma grain support
###      - Fixed a major bug in grain size determination
###        now GrainFL gives similar style and better result than GrainFactory3mod
###        so change default "g*size" value back to GrainFactory3mod's
###      - Minor improvements and bug fixes
###      - Removed dither.avsi requirement, add RemoveGrain requirement
###      - Use float for "ontop_grain" instead of int
###      - Renamed "dither" to "ditherD", add "grainD"
###
### v1.0 - 26 September 2011
###      - First release
###
### +---------+
### |  USAGE  |
### +---------+
###
### 8-bit input, 8-bit output, using internal dither down method
### GrainFL()
### 
### 8-bit input, 16-bit output
### GrainFL(lsb=true)
### 
### 16-bit input, 16-bit output
### GrainFL(lsb=true, lsb_in=true)
### 
### 16-bit input, 8-bit output, using internal dithering down method
### GrainFL(lsb_in=true)
### 
### 16-bit input, 8-bit output, using self defined dithering f3kdb_dither
### GrainFL(lsb_in=true, ditherC="f3kdb_dither()")
###
### See below for explanation of parameters
###
### +----------------+
### |  REQUIREMENTS  |
### +----------------+
###
### -> AddGrainC         [v1.7.1]
### -> RgTools          [v0.92.1]
### -> MaskTools2        [v2.0b1]
### -> dither           [v1.26.5]
### -> f3kdb             [v1.5.1]
### -> f3kgrain            [v0.4]
###

Function GrainFL(clip clp,
 \               float "g1str",     float "g2str",     float  "g3str",
 \               float "g1cstr",    float "g2cstr",    float  "g3cstr",
 \               int   "g1shrp",    int   "g2shrp",    int    "g3shrp",
 \               float "g1size",    float "g2size",    float  "g3size",
 \               float "g1soft",    float "g2soft",    float  "g3soft",
 \               int   "th1",       int   "th2",       int    "th3",      int    "th4", 
 \               float "ontop_grain",
 \               float "ontop_cgrain",
 \               float "ontop_soft",
 \               bool  "lsb",       bool  "lsb_in",
 \               int   "ditherD",   float "grainD",    string "ditherC")
{

g1str        = Default( g1str,         15 )  # [ 0 - ???] strength of luma grain / for dark areas, the strength of this value is different from 8-bit GrainFactory3mod
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
g2str        = Default( g2str,         10 )  # [ 0 - ???] strength of luma grain / for midtone areas, the strength of this value is different from 8-bit GrainFactory3mod
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
g3str        = Default( g3str,          5 )  # [ 0 - ???] strength of luma grain / for bright areas, the strength of this value is different from 8-bit GrainFactory3mod
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
g1cstr       = Default( g1cstr,         0 )  # [ 0 - ???] strength of chroma grain / for dark areas, the strength of this value is different from 8-bit GrainFactory3mod
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
g2cstr       = Default( g2cstr,         0 )  # [ 0 - ???] strength of chroma grain / for midtone areas, the strength of this value is different from 8-bit GrainFactory3mod
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
g3cstr       = Default( g3cstr,         0 )  # [ 0 - ???] strength of chroma grain / for bright areas, the strength of this value is different from 8-bit GrainFactory3mod
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
g1shrp       = Default( g1shrp,        60 )  # [ 0 - 100] sharpness of grain / for dark areas (NO EFFECT when g1size=1.0 !!)
g2shrp       = Default( g2shrp,        66 )  # [ 0 - 100] sharpness of grain / for midtone areas (NO EFFECT when g2size=1.0 !!)
g3shrp       = Default( g3shrp,        80 )  # [ 0 - 100] sharpness of grain / for bright areas (NO EFFECT when g3size=1.0 !!)
g1size       = Default( g1size,      1.50 )  # [0.5 - 4.0] size of grain / for dark areas
g2size       = Default( g2size,      1.20 )  # [0.5 - 4.0] size of grain / for mid-tone areas
g3size       = Default( g3size,      0.90 )  # [0.5 - 4.0] size of grain / for bright areas
g1soft       = Default( g1soft,         1 )  # [1.0 - 100] Noise temporal stability of grain / for dark areas, completely static if set to 100 or above
g2soft       = Default( g2soft,         1 )  # [1.0 - 100] Noise temporal stability of grain / for midtone areas, completely static if set to 100 or above
g3soft       = Default( g3soft,         1 )  # [1.0 - 100] Noise temporal stability of grain / for bright areas, completely static if set to 100 or above
th1          = Default( th1,           24 )  # Start of dark->midtone   mixing zone as defined in 8-bit precision
th2          = Default( th2,           56 )  # End   of dark->midtone   mixing zone as defined in 8-bit precision
th3          = Default( th3,          128 )  # Start of midtone->bright mixing zone as defined in 8-bit precision
th4          = Default( th4,          160 )  # End   of midtone->bright mixing zone as defined in 8-bit precision
ontop_grain  = Default( ontop_grain,    0 )  # [ 0 - ???] additional luma grain to put on top of prev. generated grain
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
ontop_cgrain = Default( ontop_cgrain,   0 )  # [ 0 - ???] additional chroma grain to put on top of prev. generated grain
                                             # positive value for add_grain16 strength, negative value for f3kgrain strength
ontop_soft   = Default( ontop_soft,     1 )  # [1.0 - 100] Noise temporal stability of grain / for ontop clip, completely static if set to 100 or above
lsb_in       = Default( lsb_in,     false )  # Input clip is 16-bit stacked or not
lsb          = Default( lsb,        false )  # Output clip is 16-bit stacked or not
ditherD      = Default( ditherD,        0 )  # 16-bit to 8-bit result dithering method when lsb=false, same as "mode" in DitherPost
grainD       = Default( grainD,         0 )  # 16-bit to 8-bit result dithering grain generating strength when lsb=false, same as "ampn" in DitherPost
                                             # "ditherC": custom dither method in string,
                                             # e.g., GrainFL(ditherC="DitherPost(mode=2)") gives same result as GrainFL(dither=2)

#-----------------------------------------------------------------------------------

o    = lsb_in ? clp : clp.Dither_convert_8_to_16()
o8   = lsb_in ? clp.Dither_get_msb() : clp
oblr = o8.RemoveGrain(19, -1)
ox   = o8.width()
oy   = o8.height()
sx1  = m4(ox/float(g1size))
sy1  = m4(oy/float(g1size))
sx1a = m4((ox+sx1)/2.0)
sy1a = m4((oy+sy1)/2.0)
sx2  = m4(ox/float(g2size))
sy2  = m4(oy/float(g2size))
sx2a = m4((ox+sx2)/2.0)
sy2a = m4((oy+sy2)/2.0)
sx3  = m4(ox/float(g3size))
sy3  = m4(oy/float(g3size))
sx3a = m4((ox+sx3)/2.0)
sy3a = m4((oy+sy3)/2.0)

b1   = g1shrp/(-50.0) + 1.0
b2   = g2shrp/(-50.0) + 1.0
b3   = g3shrp/(-50.0) + 1.0
b1a  = b1/2.0
b2a  = b2/2.0
b3a  = b3/2.0
c1   = (1.0-b1)/2.0
c2   = (1.0-b2)/2.0
c3   = (1.0-b3)/2.0
c1a  = (1.0-b1a)/2.0
c2a  = (1.0-b2a)/2.0
c3a  = (1.0-b3a)/2.0
th1str = string(th1)
th2str = string(th2)
th3str = string(th3)
th4str = string(th4)

chroma  = ( g1cstr == 0 ) && ( g2cstr == 0 ) && ( g3cstr == 0 ) ? false : true
ochroma = ( ontop_cgrain != 0 ) || chroma ? true : false

#-----------------------------------------------------------------------------------

grainLayer1 = BlankClip(o8, width=sx1, height=sy1, color_yuv=$808080)
grainLayer1 = (g1str>0 || g1cstr>0) ? grainLayer1.GrainFL_add_grain16(var=g1str>0?g1str:0, uvar=g1cstr>0?g1cstr:0, soft=g1soft, lsb_in=false)
          \ : grainLayer1.Dither_convert_8_to_16()
grainLayer1 = (g1str<=-1 || g1cstr<=-1) ? grainLayer1.f3kgrain(luma=g1str<=-1?Int(-g1str):0, chroma=g1cstr<=-1?Int(-g1cstr):0, temp=g1soft, adapt=-1, lsb=true)
          \ : grainLayer1

grainLayer1 = (g1size == 1.0 || sx1==ox && sy1==oy) ? grainLayer1
          \ : (g1size > 1.5) ? grainLayer1.Dither_resize16(sx1a, sy1a, a1=b1a, a2=c1a, kernel="bicubic")
                                        \ .Dither_resize16(ox,   oy,   a1=b1a, a2=c1a, kernel="bicubic")
                           \ : grainLayer1.Dither_resize16(ox,   oy,   a1=b1,  a2=c1,  kernel="bicubic")

#-----------------------------------------------------------------------------------

grainLayer2 = BlankClip(o8, width=sx2, height=sy2, color_yuv=$808080)
grainLayer2 = (g2str>0 || g2cstr>0) ? grainLayer2.GrainFL_add_grain16(var=g2str>0?g2str:0, uvar=g2cstr>0?g2cstr:0, soft=g2soft, lsb_in=false)
          \ : grainLayer2.Dither_convert_8_to_16()
grainLayer2 = (g2str<=-1 || g2cstr<=-1) ? grainLayer2.f3kgrain(luma=g2str<=-1?Int(-g2str):0, chroma=g2cstr<=-1?Int(-g2cstr):0, temp=g2soft, adapt=-1, lsb=true)
          \ : grainLayer2

grainLayer2 = (g2size==1.0 || sx2==ox && sy2==oy) ? grainLayer2
          \ : (g2size > 1.5) ? grainLayer2.Dither_resize16(sx2a, sy2a, a1=b2a, a2=c2a, kernel="bicubic")
                                        \ .Dither_resize16(ox,   oy,   a1=b2a, a2=c2a, kernel="bicubic")
                           \ : grainLayer2.Dither_resize16(ox,   oy,   a1=b2,  a2=c2,  kernel="bicubic")

#-----------------------------------------------------------------------------------

grainLayer3 = BlankClip(o8, width=sx3, height=sy3, color_yuv=$808080)
grainLayer3 = (g3str>0 || g3cstr>0) ? grainLayer3.GrainFL_add_grain16(var=g3str>0?g3str:0, uvar=g3cstr>0?g3cstr:0, soft=g3soft, lsb_in=false)
          \ : grainLayer3.Dither_convert_8_to_16()
grainLayer3 = (g3str<=-1 || g3cstr<=-1) ? grainLayer3.f3kgrain(luma=g3str<=-1?Int(-g3str):0, chroma=g3cstr<=-1?Int(-g3cstr):0, temp=g3soft, adapt=-1, lsb=true)
          \ : grainLayer3

grainLayer3 = (g3size==1.0 || sx3==ox && sy3==oy) ? grainLayer3
          \ : (g3size > 1.5) ? grainLayer3.Dither_resize16(sx3a, sy3a, a1=b3a, a2=c3a, kernel="bicubic")
                                        \ .Dither_resize16(ox,   oy,   a1=b3a, a2=c3a, kernel="bicubic")
                           \ : grainLayer3.Dither_resize16(ox,   oy,   a1=b3,  a2=c3,  kernel="bicubic")

#-----------------------------------------------------------------------------------

grainLayer = grainLayer1
          \ .GrainFL_merge16_8(grainLayer2,
          \                    oblr.mt_lut("x "+th1str+" < 0 x "+th2str+" > 255 255 "+th2str+" "+th1str+" - / x "+th1str+" - * ? ?", U=1, V=1),
          \                    luma=chroma,
          \                    U=chroma?3:1, V=chroma?3:1)
          \ .GrainFL_merge16_8(grainLayer3,
          \                    oblr.mt_lut("x "+th3str+" < 0 x "+th4str+" > 255 255 "+th4str+" "+th3str+" - / x "+th3str+" - * ? ?", U=1, V=1),
          \                    luma=chroma,
          \                    U=chroma?3:1, V=chroma?3:1)

#-----------------------------------------------------------------------------------

grainLayer = (  ontop_grain>0  ||  ontop_cgrain>0  ) ? grainLayer.GrainFL_add_grain16(var=ontop_grain>0?ontop_grain:0, uvar=ontop_cgrain>0?ontop_cgrain:0, soft=ontop_soft, lsb_in=true)
         \ : grainLayer
grainLayer = ( ontop_grain<=-1 || ontop_cgrain<=-1 ) ? grainLayer.f3kgrain(luma=ontop_grain<=-1?Int(-ontop_grain):0, chroma=ontop_cgrain<=-1?Int(-ontop_cgrain):0, temp=ontop_soft, adapt=-1, lsb=true)
         \ : grainLayer

#-----------------------------------------------------------------------------------

result16 = o.Dither_add16(grainLayer, dif=true, U=ochroma?3:2, V=ochroma?3:2)
result   = lsb ? result16 : Defined(ditherC) ? Eval("result16."+ditherC) : result16.DitherPost(mode=ditherD, ampn=grainD)

return result
}

#===================================================================================
function m4(float x) {return( x<16?16:int(round(x/4.0)*4)) }


Function GrainFL_merge16_8(clip src1, clip src2, clip mask, bool "luma", int "y", int "u", int "v"){
	luma = Default(luma, false)

	y = Default(y, 3)
	u = Default(u, 2)
	v = Default(v, 2)

	mask16 = StackVertical(mask, mask)
	Dither_merge16(src1, src2, mask16, luma=luma, y=y, u=u, v=v)
}

Function GrainFL_lut16 (clip src,
\	string "expr", string "yexpr", string "uexpr", string "vexpr",
\	int "y", int "u", int "v")
{
	s_msb = Dither_get_msb (src)
	s_lsb = Dither_get_lsb (src)

	d_msb = GrainFL_lut16_msb (s_msb, s_lsb,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
	d_lsb = GrainFL_lut16_lsb (s_msb, s_lsb,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)

	StackVertical (d_msb, d_lsb)
}

Function GrainFL_lut16_msb (clip msb, clip lsb,
\	string "expr", string "yexpr", string "uexpr", string "vexpr",
\	int "y", int "u", int "v")
{
	expr  = Default (expr,  "x")
	yexpr = Default (yexpr, expr)
	uexpr = Default (uexpr, expr)
	vexpr = Default (vexpr, expr)
	expr  = GrainFL_lut16_expr (expr,  True)
	yexpr = GrainFL_lut16_expr (yexpr, True)
	uexpr = GrainFL_lut16_expr (uexpr, True)
	vexpr = GrainFL_lut16_expr (vexpr, True)

	y = (Defined (y) && y < 0) ? y / 256 : y
	u = (Defined (u) && u < 0) ? u / 256 : u
	v = (Defined (v) && v < 0) ? v / 256 : v

	mt_lutxy (msb, lsb,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
}

Function GrainFL_lut16_lsb (clip msb, clip lsb,
\	string "expr", string "yexpr", string "uexpr", string "vexpr",
\	int "y", int "u", int "v")
{
	expr  = Default (expr,  "x")
	yexpr = Default (yexpr, expr)
	uexpr = Default (uexpr, expr)
	vexpr = Default (vexpr, expr)
	expr  = GrainFL_lut16_expr (expr,  False)
	yexpr = GrainFL_lut16_expr (yexpr, False)
	uexpr = GrainFL_lut16_expr (uexpr, False)
	vexpr = GrainFL_lut16_expr (vexpr, False)

	y = (Defined (y) && y < 0) ? y % 256 : y
	u = (Defined (u) && u < 0) ? u % 256 : u
	v = (Defined (v) && v < 0) ? v % 256 : v

	mt_lutxy (lsb, msb,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
}

Function GrainFL_lut16_expr (string expr, bool gmsb)
{
	# We use spaces to enclose " x " because we don't want operators
	# like "max" or "exp" to have their "x" replaced...
	repstr = (gmsb) ? " x 256 * y + " : " y 256 * x + "
	expr = GrainFL_replace_string (" " + expr + " ", " x ", repstr)
	part = GrainFL_expr_part (gmsb)
	expr = expr + part

	return (expr)
}

Function GrainFL_lut8 (clip src,
\	string "expr", string "yexpr", string "uexpr", string "vexpr",
\	int "y", int "u", int "v")
{
	d_msb = GrainFL_lut8_msb (src,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
	d_lsb = GrainFL_lut8_lsb (src,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)

	StackVertical (d_msb, d_lsb)
}

Function GrainFL_lut8_msb (clip src,
\	string "expr", string "yexpr", string "uexpr", string "vexpr",
\	int "y", int "u", int "v")
{
	expr  = Default (expr,  "x")
	yexpr = Default (yexpr, expr)
	uexpr = Default (uexpr, expr)
	vexpr = Default (vexpr, expr)
	part  = GrainFL_expr_part (true)
	expr  = expr  + part
	yexpr = yexpr + part
	uexpr = uexpr + part
	vexpr = vexpr + part
	y = (Defined (y) && y < 0) ? y / 256 : y
	u = (Defined (u) && u < 0) ? u / 256 : u
	v = (Defined (v) && v < 0) ? v / 256 : v

	mt_lut (src, expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
}

Function GrainFL_lut8_lsb (clip src,
\	string "expr", string "yexpr", string "uexpr", string "vexpr",
\	int "y", int "u", int "v")
{
	expr  = Default (expr,  "x")
	yexpr = Default (yexpr, expr)
	uexpr = Default (uexpr, expr)
	vexpr = Default (vexpr, expr)
	part  = GrainFL_expr_part (false)
	expr  = expr  + part
	yexpr = yexpr + part
	uexpr = uexpr + part
	vexpr = vexpr + part
	y = (Defined (y)) ? ((y==2 || y==4 || y==5) ? 0 : (y < 0) ? y % 256 : y) : y
	u = (Defined (u)) ? ((u==2 || u==4 || u==5) ? 0 : (u < 0) ? u % 256 : u) : u
	v = (Defined (v)) ? ((v==2 || v==4 || v==5) ? 0 : (v < 0) ? v % 256 : v) : v

	mt_lut (src, expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
}

Function GrainFL_expr_part(bool gmsb){
	part = (gmsb) ? "8 >>u " : "255 &u "
	expr = " 0 65535 clip " + part

	return (expr)
}

Function GrainFL_replace_string (string str, string findstr, string repstr)
{
	strl     = LCase (str)
	findstrl = LCase (findstr)
	lenf     = StrLen (findstr)

	pos = FindStr (strl, findstrl)
	pos2 = (pos <= 0) ? 1 : pos
	rep  = (pos <= 0) ? "" : LeftStr (str, pos-1) + repstr + GrainFL_replace_string (MidStr (str, pos + lenf), findstr, repstr)

	return ((pos <= 0) ? str : rep)
}

Function GrainFL_add_grain16 (clip src, float "var", float "uvar",
\	float "soft", int "maxts", bool "replace", bool "lsb_in")
{
	var     = Default (var,  1.0)
	uvar    = Default (uvar, 0.0)
	replace = Default (replace, false)
	lsb_in  = Default (lsb_in,   true)

	src

	template = (lsb_in) ? Dither_get_msb () : last
	grain = template.GrainFL_gen_grain_internal (
\		soft=soft, maxts=maxts, var=64, uvar=64)
	grain = grain.GrainFL_lut8 (
\		expr="x 128 - 4 * "+String(uvar)+" * 32768 +",
\		yexpr="x 128 - 4 * "+String(var)+" * 32768 +",
\		y=3, u=3, v=3
\	)

	(! replace && ! lsb_in) ? Dither_convert_8_to_16 () : last
	(  replace            ) ? grain : Dither_add16 (last, grain, dif=true)
}

Function GrainFL_gen_grain_internal (clip template,
\	float "soft", int "maxts", float "var", float "uvar")
{
	soft    = Default (soft, 1.0)
	maxts   = Default (maxts,  5)
	var     = Default (var,  1.0)
	uvar    = Default (uvar, 0.0)
	Assert (soft  >= 1.0)
	Assert (maxts >= 0)

	thr_aft  = 10.0
	constant = (soft >= 100)

	ts_rad   = (constant)   ? 0 : Ceil ((soft - 1) * 0.5)
	ts_rad   = (ts_rad > maxts) ? maxts : ts_rad

	rate_mul = (constant)   ? 1 : soft / Float (ts_rad * 2 + 1)
	decim    = (rate_mul < 2.0/3.0) ? 2.0 : 1.0

	amp_comp = pow (ts_rad * 2 + 1, 0.75)

	pa_l_max = 128.0 /  var
	pa_c_max = 128.0 / uvar
	a_l_pre  = (amp_comp > pa_l_max) ? pa_l_max : amp_comp
	a_c_pre  = (amp_comp > pa_c_max) ? pa_c_max : amp_comp
	a_l_post = amp_comp / a_l_pre
	a_c_post = amp_comp / a_c_pre
	a_l_str  = "x 128 - "+String(a_l_post)+" * 128 +"
	a_c_str  = "x 128 - "+String(a_c_post)+" * 128 +"

	p_l      = (a_l_post == 1.0 &&  var <= 0.01) ? 2 : 3
	p_c      = (a_c_post == 1.0 && uvar <= 0.01) ? 2 : 3
	amp_bef  = (ts_rad > 0 && (p_l == 3 || p_c == 3) && var >  thr_aft)
	amp_aft  = (ts_rad > 0 && (p_l == 3 || p_c == 3) && var <= thr_aft)

	len      = template.FrameCount ()
	template.mt_lut(y=-128,u=-128,v=-128)

	AddGrainC (var=var*a_l_pre, uvar=uvar*a_c_pre, constant=constant)
	(! constant && ts_rad > 0) ? TemporalSoften (ts_rad, 255, 255) : last
	(! constant && ts_rad > 0) ? Trim (ts_rad, 0) : last
	(! constant &&    amp_bef) ? mt_lut (yexpr=a_l_str, expr=a_c_str, y=p_l, u=p_c, v=p_c) : last

	(! constant &&  decim > 1) ? SelectEven () : last
	(! constant              ) ? ConvertFPS (FrameRate () * rate_mul * decim) : last
	(! constant &&    amp_aft) ? mt_lut (yexpr=a_l_str, expr=a_c_str, y=p_l, u=p_c, v=p_c) : last

	AssumeFPS (template.FrameRateNumerator (), template.FrameRateDenominator ())
	Assert (FrameCount () >= len)
	Trim (0, -len)
}
