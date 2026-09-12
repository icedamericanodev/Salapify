def lum(h):
    h=h.lstrip('#'); r,g,b=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    f=lambda c: c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
    return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)
def cr(a,b):
    la,lb=lum(a),lum(b); hi,lo=max(la,lb),min(la,lb); return round((hi+0.05)/(lo+0.05),2)
L={'bg':'#F6F4F0','surface':'#FFFFFF','border':'#E4DFD7','text':'#1C1917','textSecondary':'#5C5751','textMuted':'#8A847C',
   'accent':'#BE3A1B','onAccent':'#FFFFFF','accentSoft':'#FCE8E1','positive':'#1B7A47','positiveSoft':'#DCF3E4',
   'negative':'#B91F2E','negativeSoft':'#FBE1E2','warning':'#8F5600','warningSoft':'#FBEAC9'}
D={'bg':'#1A1815','surface':'#25221E','border':'#38332D','text':'#F5F1EB','textSecondary':'#B7B0A6','textMuted':'#847D74',
   'accent':'#FF8A6A','onAccent':'#2B0F07','accentSoft':'#43261E','positive':'#62D394','positiveSoft':'#1F3B2C',
   'negative':'#FF8085','negativeSoft':'#43272A','warning':'#F3BC55','warningSoft':'#3F3117'}
pairs=[('text','bg'),('text','surface'),('textSecondary','bg'),('textSecondary','surface'),('textMuted','bg'),('textMuted','surface'),
       ('accent','bg'),('accent','surface'),('onAccent','accent'),('accent','accentSoft'),('text','accentSoft'),
       ('positive','bg'),('positive','surface'),('positive','positiveSoft'),('negative','bg'),('negative','surface'),('negative','negativeSoft'),
       ('warning','bg'),('warning','surface'),('warning','warningSoft'),('border','bg'),('border','surface')]
for name,P in (('LIGHT',L),('DARK',D)):
    print(name)
    for a,b in pairs: print(f"  {a:14s} on {b:13s} {P[a]} / {P[b]}  {cr(P[a],P[b])}")
