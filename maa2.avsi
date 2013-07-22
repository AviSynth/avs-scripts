/*
MAA2 v0.2
====

Updated version of the MAA antialising script from AnimeIVTC. 
MAA2 uses tp7's SangNom2 and FTurn, which provide a nice speedup for SangNom-based antialiasing,
especially when only processing the luma plane.
The defaults of MAA2 match up with MAA, so you'll get identical output (save for the more accurate border region processing of SangNom2)
when using this script as a drop-in replacement.

MAA2 supports Y8, YV12 and YV24 input

Requirements:
	* AviSynth 2.6
	* SangNom2 
	* FTurn
	* Masktools 2.0a48
	
*/

function maa2(clip c, int "mask", bool "chroma", float "ss", int "aa", int "threads", int "show") 
{
    chroma = Default(chroma, false)   # Process chroma channels [true]/false
    mask = Default(mask, 1)           # [1]: Enable masking   0: Disable masking   -i: Enable masking with custom treshold (sensible values are  between 0 and 30)
    threads = Default(threads, 4)     # Number of threads to use for SangNom2
    aa = Default(aa, 48)              # SangNom2 antialialising strength
    mtresh = (mask < 0) ? -mask : 7 
    show = Default(show, 0)           # [0]: Don't overlay mask   1: Overlay mask only   2: Overlay mask and run AA
    ss = Default(ss, 2.0)             # Supersampling factor (sensible values are between [2.0] and 4.0)
    uv = (chroma) ? 3 : 1
	ss_w = int(round(c.width/4.0)*4)
	ss_h = int(round(c.height/4.0)*4)
    
    Assert(c.IsY8 || c.IsYV12 || c.IsYV24, "MAA2: Input must be Y8, YV12 or YV24")
    Assert(ss > 0, "MAA2: Supersampling factor must be > 0")
    
    m    = (mask != 0) ? c.mt_edge("sobel",mtresh,mtresh,mtresh-2,mtresh-2,u=uv,v=uv).mt_inflate(u=uv,v=uv) : nop()
    
    y_aa =  c.ConvertToY8().Spline36Resize(ss_w,ss_h).FTurnLeft() \
             .SangNom2(threads=threads, aa=aa).FTurnRight().SangNom2(threads=threads, aa=aa).Spline36Resize(c.width,c.height)
    u_aa = (chroma) ? c.UtoY8().Spline36Resize(ss_w,ss_h).FTurnLeft() \
             .SangNom2(threads=threads, aa=aa).FTurnRight().SangNom2(threads=threads, aa=aa).Spline36Resize(c.width,c.height) : nop()
    v_aa = (chroma) ? c.VtoY8().Spline36Resize(ss_w,ss_h).FTurnLeft() \
             .SangNom2(threads=threads, aa=aa).FTurnRight().SangNom2(threads=threads, aa=aa).Spline36Resize(c.width,c.height) : nop()
    
    c_aa =  (chroma) ? YtoUV(u_aa,v_aa,y_aa) : y_aa
   
    c_aa = (show==1) ? (c.IsY8) ? c_aa.ConvertToYV12().mt_lut(y=2, u=0,v=0)
							  \ : c.mt_lut("x 2 /", y=2, u=3,v=3)
       \ : (show==2) ? (c.IsY8) ? c_aa.ConvertToYV12().mt_lut(y=2, u=0,v=0) 
					          \ : YtoUV(c.UtoY8(), c.VtoY8(), y_aa).mt_lut("x 2 /", y=2, u=3,v=3) 
       \ : c_aa
           
    return (mask !=0) ? (show > 0) ? (c.IsYV24) ? mt_merge(c,c_aa,m.YtoUV(m,m),u=3,v=3)
                                              \ : mt_merge(c.ConvertToYV12(),c_aa,m,u=3,v=3, luma=true)
                    \ : (chroma) ? mt_merge(c,c_aa,m,u=3,v=3)
                    \ : mt_merge(c,c_aa,m,u=2,v=2)
      \ :  c_aa.MergeChroma(c)
}