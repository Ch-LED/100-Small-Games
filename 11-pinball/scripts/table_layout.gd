class_name PinballLayout
extends RefCounted
## The Space Cadet table, copied from the original (playbook: the "参考" section
## of the design doc).
##
## Every number here comes out of the original PINBALL.DAT dump -- the walls are
## its 64 wall runs verbatim, and every mechanism sits where the original put it.
## **x is negated on the way in**: the original's x runs positive to the LEFT,
## this project's runs right, so the numbers below are its coordinates mirrored.
##
## Table space: x across (left negative, right positive), z along with **-z at
## the far, raised end**. The table node carries the tilt, so nothing here knows
## the table is sloped.

## The table spans x -8..8 and z -14..13.88, all of it in the wall runs below.

## Ball radius, from the original's ball group.
const BALL_RADIUS := 0.3
## Past this line the ball is gone. The original's drain is a line across the
## very bottom of the table.
const DRAIN_Z := 14.437
## The launch lane runs up the right-hand side, between this wall and the outer
## edge -- the original's wall run g293, which puts the lane at x 6.5..7.5, one
## and a bit ball-widths wide. Used only to tell "the ball is back in the lane"
## from "the ball is at rest somewhere on the playfield".
const LANE_INNER_X := 6.5


## The original's wall runs, one entry each. 64 of them: the table outline is
## only the first few, everything after is an inner channel.
static func wall_polylines() -> Array[PackedVector2Array]:
	var polylines: Array[PackedVector2Array] = [
		# g280
		PackedVector2Array([Vector2(7.98545, -4.97790), Vector2(8.00267, -13.98625), Vector2(1.40573, -12.36716), Vector2(2.18083, -12.16047), Vector2(2.93870, -11.88488), Vector2(3.62768, -11.55761), Vector2(4.29943, -11.14423), Vector2(4.90228, -10.66194), Vector2(5.48791, -10.09354), Vector2(5.97019, -9.55959), Vector2(6.43525, -8.87061), Vector2(6.77974, -8.18163), Vector2(7.07256, -7.45821), Vector2(7.29647, -6.63144), Vector2(7.43427, -5.89079), Vector2(7.48594, -5.11569), Vector2(7.48594, -5.01235), Vector2(7.98545, -4.97790)]),
		# g281
		PackedVector2Array([Vector2(-3.83256, -13.44587), Vector2(-8.00032, -14.00000), Vector2(-7.50032, -11.00000), Vector2(-7.43217, -11.51764), Vector2(-7.23237, -12.00000), Vector2(-6.91453, -12.41421), Vector2(-6.50032, -12.73205), Vector2(-6.01796, -12.93185), Vector2(-5.50032, -13.00000), Vector2(-4.98268, -12.93185), Vector2(-4.38665, -12.74952), Vector2(-3.83256, -13.44587)]),
		# g282
		PackedVector2Array([Vector2(2.95764, -10.76953), Vector2(2.59726, -10.61186), Vector2(2.34949, -10.25148), Vector2(2.79997, -9.73343), Vector2(3.07026, -9.95867), Vector2(3.45317, -9.93614), Vector2(3.63336, -9.80100), Vector2(4.28656, -9.26042), Vector2(4.93975, -8.42703), Vector2(5.45780, -7.54860), Vector2(5.79566, -6.58007), Vector2(5.97586, -5.54396), Vector2(5.95333, -4.46281), Vector2(5.79566, -3.44923), Vector2(5.70557, -3.15642), Vector2(5.86324, -3.11137), Vector2(6.11100, -4.37271), Vector2(6.31372, -5.31872), Vector2(6.31372, -6.42240), Vector2(5.99838, -7.50355), Vector2(5.41276, -8.56218), Vector2(4.78209, -9.41809), Vector2(3.92617, -10.18391), Vector2(2.95764, -10.76953)]),
		# g283
		PackedVector2Array([Vector2(5.72173, -3.16126), Vector2(4.34591, 0.34167), Vector2(4.37175, 2.69276), Vector2(4.50093, 2.79610), Vector2(4.57844, 2.69276), Vector2(5.48270, 3.41617), Vector2(5.48270, -0.82096), Vector2(5.61188, -2.02451), Vector2(5.80427, -2.95224), Vector2(6.12702, -4.21900), Vector2(6.37266, -5.32995), Vector2(6.30946, -5.34228), Vector2(5.79274, -3.19788), Vector2(5.72173, -3.16126)]),
		# g284
		PackedVector2Array([Vector2(-3.62414, -8.00926), Vector2(-3.51517, -8.00640), Vector2(-1.89732, -9.00141), Vector2(-1.76579, -9.09651), Vector2(-1.72837, -9.18989), Vector2(-1.71492, -9.98494), Vector2(-1.76246, -10.12057), Vector2(-2.71339, -10.80632), Vector2(-2.88823, -10.84216), Vector2(-3.05748, -10.72549), Vector2(-3.08292, -10.55151), Vector2(-2.47042, -9.70879), Vector2(-3.33884, -9.03889), Vector2(-3.62683, -9.38769), Vector2(-3.72374, -9.37376), Vector2(-3.76958, -9.23320), Vector2(-3.78750, -8.22428), Vector2(-3.72947, -8.07437), Vector2(-3.62414, -8.00926)]),
		# g285
		PackedVector2Array([Vector2(-3.62552, 12.54637), Vector2(-6.50317, 10.49329), Vector2(-6.87939, 12.13949), Vector2(-6.94327, 12.38618), Vector2(-7.17896, 12.39214), Vector2(-7.50763, 10.53764), Vector2(-7.81221, 10.52768), Vector2(-7.84540, 13.85593), Vector2(-3.55440, 13.85477), Vector2(-3.55080, 12.67558), Vector2(-3.62552, 12.54637)]),
		# g286
		PackedVector2Array([Vector2(-7.76000, 13.00000), Vector2(-7.51000, 13.00000), Vector2(-7.51000, -7.00000), Vector2(-7.76000, -7.00000), Vector2(-7.76000, 13.00000)]),
		# g287
		PackedVector2Array([Vector2(7.51000, 13.00000), Vector2(7.76000, 13.00000), Vector2(7.76000, -7.00000), Vector2(7.51000, -7.00000), Vector2(7.51000, 13.00000)]),
		# g288
		PackedVector2Array([Vector2(-4.01526, 7.43394), Vector2(-3.88252, 7.16016), Vector2(-3.93229, 6.99424), Vector2(-4.07333, 6.93616), Vector2(-4.21437, 6.96105), Vector2(-4.29733, 7.07720), Vector2(-4.31949, 9.33304), Vector2(-4.20522, 9.52203), Vector2(-3.05430, 10.30592), Vector2(-2.84775, 10.34654), Vector2(-2.73346, 10.24694), Vector2(-2.68826, 10.06349), Vector2(-2.78966, 9.94373), Vector2(-2.97948, 9.95217), Vector2(-4.01526, 7.43394)]),
		# g289
		PackedVector2Array([Vector2(-5.47500, 8.37500), Vector2(-5.22500, 8.37500), Vector2(-5.22500, 7.12500), Vector2(-5.47500, 7.12500), Vector2(-5.47500, 8.37500)]),
		# g290
		PackedVector2Array([Vector2(-6.50000, 8.87500), Vector2(-6.25000, 8.87500), Vector2(-6.25000, 7.12500), Vector2(-6.50000, 7.12500), Vector2(-6.50000, 8.87500)]),
		# g291
		PackedVector2Array([Vector2(3.55110, 12.69511), Vector2(3.55469, 13.87429), Vector2(6.41065, 13.87542), Vector2(6.40881, 11.32086), Vector2(6.27511, 10.87977), Vector2(6.24798, 12.10639), Vector2(5.92473, 11.82390), Vector2(5.50249, 11.60316), Vector2(5.28903, 11.26483), Vector2(3.62581, 12.56590), Vector2(3.55110, 12.69511)]),
		# g292
		PackedVector2Array([Vector2(5.22441, 9.71315), Vector2(5.47559, 9.71315), Vector2(5.47559, 7.11930), Vector2(5.22441, 7.11930), Vector2(5.22441, 9.71315)]),
		# g293
		PackedVector2Array([Vector2(6.25000, 12.85000), Vector2(6.50000, 12.85000), Vector2(6.50000, 4.85000), Vector2(6.25000, 4.85000), Vector2(6.25000, 12.85000)]),
		# g294
		PackedVector2Array([Vector2(0.75000, -9.12500), Vector2(0.75000, -9.87500), Vector2(0.50000, -9.87500), Vector2(0.50000, -9.12500), Vector2(0.75000, -9.12500)]),
		# g295
		PackedVector2Array([Vector2(-0.50000, -9.12500), Vector2(-0.50000, -9.87500), Vector2(-0.75000, -9.87500), Vector2(-0.75000, -9.12500), Vector2(-0.50000, -9.12500)]),
		# g296
		PackedVector2Array([Vector2(3.53566, -8.54775), Vector2(3.22385, -8.85955), Vector2(2.88807, -9.17135), Vector2(2.75615, -9.39921), Vector2(2.75615, -9.56710), Vector2(2.86408, -9.73499), Vector2(2.99600, -9.89089), Vector2(3.24784, -9.96285), Vector2(3.47569, -9.92687), Vector2(3.59562, -9.81894), Vector2(3.95539, -10.17871), Vector2(3.06795, -10.75434), Vector2(2.94803, -10.81430), Vector2(2.80412, -10.83829), Vector2(2.70818, -10.81430), Vector2(1.76079, -10.11875), Vector2(1.71282, -10.01082), Vector2(1.71282, -9.21932), Vector2(1.78477, -9.09940), Vector2(2.00064, -8.97948), Vector2(2.09658, -8.97948), Vector2(2.48033, -9.32725), Vector2(2.55228, -9.32725), Vector2(3.15190, -8.72764), Vector2(3.16389, -8.64369), Vector2(2.81611, -8.29591), Vector2(2.87608, -8.16400), Vector2(3.53566, -8.54775)]),
		# g297
		PackedVector2Array([Vector2(-3.85004, -13.44701), Vector2(-2.88597, -12.85842), Vector2(-3.64708, -11.74213), Vector2(-3.58619, -11.61021), Vector2(-2.43946, -12.08717), Vector2(-1.68850, -12.32057), Vector2(-0.92740, -12.45250), Vector2(-0.17645, -12.50324), Vector2(0.56436, -12.49309), Vector2(1.44724, -12.36116), Vector2(1.45739, -12.36116), Vector2(-3.85004, -13.44701)]),
		# g298
		PackedVector2Array([Vector2(-1.29807, -3.01869), Vector2(0.63000, -2.34798), Vector2(0.79899, -2.41956), Vector2(0.91982, -2.56965), Vector2(0.65365, -3.19324), Vector2(0.02568, -3.87324), Vector2(-0.83815, -3.60016), Vector2(-1.41915, -3.32154), Vector2(-1.40505, -3.14510), Vector2(-1.29807, -3.01869)]),
		# g299
		PackedVector2Array([Vector2(6.25676, 3.80730), Vector2(6.51011, 3.82022), Vector2(6.51780, -0.02978), Vector2(6.25676, -0.02978), Vector2(6.25676, 3.80730)]),
		# g300
		PackedVector2Array([Vector2(-2.66511, -13.64931), Vector2(-5.47227, -13.72000), Vector2(-5.47227, -13.01316), Vector2(-4.97748, -12.94248), Vector2(-4.46250, -12.71023), Vector2(-4.07879, -12.41740), Vector2(-3.77586, -12.00339), Vector2(-3.60420, -11.58939), Vector2(-2.36218, -12.17505), Vector2(-2.66511, -13.64931)]),
		# g301
		PackedVector2Array([Vector2(2.97948, 9.95217), Vector2(2.78966, 9.94373), Vector2(2.68826, 10.06349), Vector2(2.73346, 10.24694), Vector2(2.84775, 10.34654), Vector2(3.05430, 10.30592), Vector2(4.20522, 9.52203), Vector2(4.31949, 9.33304), Vector2(4.29733, 7.07720), Vector2(4.21437, 6.96105), Vector2(4.07333, 6.93616), Vector2(3.93229, 6.99424), Vector2(3.88252, 7.16016), Vector2(4.01526, 7.43394), Vector2(2.97948, 9.95217)]),
		# g302
		PackedVector2Array([Vector2(-6.24044, -6.15063), Vector2(-6.44963, -6.03652), Vector2(-6.56374, -5.52304), Vector2(-6.56374, -4.57215), Vector2(-6.43061, -3.60224), Vector2(-6.12633, -2.59429), Vector2(-5.68892, -1.70045), Vector2(-5.11838, -0.90170), Vector2(-4.77606, -0.61643), Vector2(-4.56686, -0.59741), Vector2(-3.14052, -1.45322), Vector2(-3.02642, -1.60536), Vector2(-3.00740, -1.96670), Vector2(-3.06445, -2.04277), Vector2(-3.14052, -2.09983), Vector2(-3.27365, -2.00474), Vector2(-3.31169, -1.92866), Vector2(-5.38463, -3.05072), Vector2(-5.32758, -3.22188), Vector2(-5.36562, -3.29795), Vector2(-5.46070, -3.35500), Vector2(-5.66990, -3.54518), Vector2(-5.84106, -3.90652), Vector2(-5.99320, -4.34393), Vector2(-6.06928, -4.78134), Vector2(-6.06928, -5.27581), Vector2(-6.06928, -5.71322), Vector2(-6.08829, -6.01750), Vector2(-6.24044, -6.15063)]),
		# g303
		PackedVector2Array([Vector2(-6.50967, 5.61845), Vector2(-6.03192, 5.37957), Vector2(-5.04988, 5.19378), Vector2(-4.83755, 5.08762), Vector2(-4.73138, 4.82220), Vector2(-4.73138, 2.43345), Vector2(-6.56276, -1.44163), Vector2(-6.58930, 5.64499), Vector2(-6.50967, 5.61845)]),
		# g304
		PackedVector2Array([Vector2(3.23910, -8.69911), Vector2(2.80754, -8.31935), Vector2(2.84207, -8.23304), Vector2(3.06648, -7.97410), Vector2(3.37719, -7.45624), Vector2(3.63613, -6.93838), Vector2(3.84327, -6.42051), Vector2(3.99863, -5.83360), Vector2(3.98137, -5.26395), Vector2(3.92958, -4.93597), Vector2(3.99863, -4.83240), Vector2(4.08494, -4.79787), Vector2(4.13673, -4.72882), Vector2(3.18731, -2.70916), Vector2(3.13552, -2.72642), Vector2(3.10100, -2.74368), Vector2(3.04921, -2.72642), Vector2(2.98016, -2.58832), Vector2(2.99743, -2.53654), Vector2(3.42898, -2.31213), Vector2(3.98137, -2.95083), Vector2(4.44745, -3.58953), Vector2(4.72364, -4.14191), Vector2(4.93078, -4.88418), Vector2(4.94805, -5.64372), Vector2(4.77543, -6.38599), Vector2(4.53376, -7.09374), Vector2(4.17125, -7.76696), Vector2(3.72244, -8.33661), Vector2(3.35993, -8.69911), Vector2(3.23910, -8.69911)]),
		# g305
		PackedVector2Array([Vector2(-7.51847, -5.77947), Vector2(-7.37936, -6.55844), Vector2(-7.15680, -7.39306), Vector2(-6.70728, -8.14134), Vector2(-6.24939, -8.69336), Vector2(-6.25227, -9.17899), Vector2(-6.93424, -9.59088), Vector2(-7.24026, -10.00818), Vector2(-7.43501, -10.45331), Vector2(-7.51847, -10.87062), Vector2(-7.43501, -11.59395), Vector2(-7.24026, -12.03908), Vector2(-6.93424, -12.45638), Vector2(-6.51693, -12.73459), Vector2(-6.07180, -12.95715), Vector2(-5.48757, -13.04061), Vector2(-5.40411, -13.93087), Vector2(-7.88013, -13.93087), Vector2(-7.88013, -4.72229), Vector2(-7.51847, -4.72229), Vector2(-7.51847, -5.77947)]),
		# g306
		PackedVector2Array([Vector2(-5.76507, 2.47803), Vector2(-5.76507, 1.97146), Vector2(-5.95809, 1.97146), Vector2(-5.95809, 2.47803), Vector2(-5.76507, 2.47803)]),
		# g307
		PackedVector2Array([Vector2(-6.74857, 2.21052), Vector2(-6.74857, 1.70395), Vector2(-6.94160, 1.70395), Vector2(-6.94160, 2.21052), Vector2(-6.74857, 2.21052)]),
		# g308
		PackedVector2Array([Vector2(-7.69519, 4.51621), Vector2(-7.30687, 4.17203), Vector2(-7.21136, 3.63870), Vector2(-7.21526, 3.30521), Vector2(-7.28907, 2.85792), Vector2(-7.69158, 2.51064), Vector2(-7.69519, 4.51621)]),
		# g309
		PackedVector2Array([Vector2(-4.75526, 3.02098), Vector2(-5.14817, 3.36164), Vector2(-5.24074, 3.78245), Vector2(-5.23685, 4.28874), Vector2(-5.14830, 4.66432), Vector2(-4.76440, 4.95302), Vector2(-4.75526, 3.02098)]),
		# g310
		PackedVector2Array([Vector2(3.42560, -2.47753), Vector2(-0.13595, -0.99650)]),
		# g311
		PackedVector2Array([Vector2(5.32500, 5.50000), Vector2(-0.21430, -0.99650)]),
		# g313
		PackedVector2Array([Vector2(6.38223, 0.06800), Vector2(-0.12606, 0.00350)]),
		# g314
		PackedVector2Array([Vector2(6.38712, 5.02475), Vector2(-0.12606, 0.00350)]),
		# g316
		PackedVector2Array([Vector2(5.34538, 9.72709), Vector2(-0.14660, 0.00000)]),
		# g325
		PackedVector2Array([Vector2(5.29636, 3.77235), Vector2(-0.13740, 0.00272)]),
		# g326
		PackedVector2Array([Vector2(-5.85850, 1.95246), Vector2(-0.09067, 0.37113)]),
		# g327
		PackedVector2Array([Vector2(-5.85850, 2.47426), Vector2(-0.09067, 0.37113)]),
		# g328
		PackedVector2Array([Vector2(-6.84201, 1.68495), Vector2(-0.09067, 0.37113)]),
		# g329
		PackedVector2Array([Vector2(-2.56853, 11.73344), Vector2(-2.43856, 11.71788), Vector2(-6.30191, 9.01222), Vector2(-6.36898, 9.08990), Vector2(-2.56853, 11.73344)]),
		# g330
		PackedVector2Array([Vector2(5.35063, 9.77604), Vector2(5.37178, 9.67383), Vector2(2.43993, 11.72513), Vector2(2.58388, 11.73354), Vector2(5.35063, 9.77604)]),
		# g102
		PackedVector2Array([Vector2(-3.36150, 1.25822), Vector2(-3.29890, 1.24570), Vector2(-3.54930, 0.41940), Vector2(-2.35994, -0.39437), Vector2(-1.60876, 0.63224), Vector2(-1.50861, 0.58216), Vector2(-2.05947, -0.18153), Vector2(-2.51017, -0.73239), Vector2(-3.71205, 0.24413), Vector2(-3.36150, 1.25822)]),
		# g103
		PackedVector2Array([Vector2(-5.64953, -2.05291), Vector2(-5.24767, -2.02612), Vector2(-4.47548, -1.87748), Vector2(-3.77417, -1.57067), Vector2(-3.38043, -1.37878), Vector2(-3.02402, -1.08844), Vector2(-2.75612, -0.87411), Vector2(-2.35425, -0.47225), Vector2(-1.81844, 0.14394), Vector2(-1.55053, 0.54581), Vector2(-1.04036, 1.34451), Vector2(-3.17445, 2.08731), Vector2(-3.31873, 1.24237), Vector2(-3.47947, 0.70655), Vector2(-3.69380, 0.22432), Vector2(-3.93492, -0.17755), Vector2(-4.22962, -0.52583), Vector2(-4.63148, -0.82053), Vector2(-5.14051, -1.03486), Vector2(-5.62018, -1.10535), Vector2(-5.90532, -1.05907), Vector2(-6.18572, -0.89318), Vector2(-6.39968, -0.65978), Vector2(-6.48005, -0.47225), Vector2(-6.50684, -0.20434), Vector2(-6.48005, -0.04359), Vector2(-6.39491, 0.19534), Vector2(-6.24626, 0.38289), Vector2(-6.08551, 0.48012), Vector2(-5.52037, 0.71390), Vector2(-5.19151, 0.97227), Vector2(-5.03334, 1.21558), Vector2(-4.84581, 1.59065), Vector2(-4.79223, 1.91214), Vector2(-4.79223, 5.12705), Vector2(-4.84581, 5.44854), Vector2(-4.95297, 5.71645), Vector2(-5.27446, 6.11831), Vector2(-5.38163, 6.35943), Vector2(-5.40314, 6.65413), Vector2(-5.40841, 7.51199), Vector2(-5.51558, 7.72455), Vector2(-5.67632, 7.89105), Vector2(-5.89065, 7.93713), Vector2(-6.13177, 7.85851), Vector2(-6.27649, 7.64921), Vector2(-6.34077, 7.44106), Vector2(-6.33282, 6.65139), Vector2(-6.36233, 6.36492), Vector2(-6.48561, 6.09402), Vector2(-6.73194, 5.76200), Vector2(-7.27049, 5.36265), Vector2(-7.47406, 5.10027), Vector2(-7.60527, 4.77877), Vector2(-7.64557, 4.47331), Vector2(-7.64415, -0.04359), Vector2(-7.56856, -0.55262), Vector2(-7.36156, -1.06899), Vector2(-7.05954, -1.44626), Vector2(-6.64080, -1.78500), Vector2(-6.18535, -1.97254), Vector2(-5.64953, -2.05291)]),
		# g106
		PackedVector2Array([Vector2(6.47738, -0.57823), Vector2(5.44916, -0.57822), Vector2(2.96191, -11.09639), Vector2(3.66519, -10.74763), Vector2(6.47738, -0.57823)]),
		# g331
		PackedVector2Array([Vector2(2.61899, -9.49118), Vector2(1.98973, -8.86669), Vector2(2.06331, -8.79258), Vector2(2.69600, -9.41674), Vector2(2.61899, -9.49118)]),
		# g332
		PackedVector2Array([Vector2(2.62093, -8.22260), Vector2(2.71469, -8.11795), Vector2(3.17408, -8.76018), Vector2(2.62093, -8.22260)]),
		# g333
		PackedVector2Array([Vector2(-3.82448, -9.75999), Vector2(-3.67012, -9.21738), Vector2(-3.19300, -9.10044), Vector2(-3.76367, -9.82080), Vector2(-3.82448, -9.75999)]),
		# g334
		PackedVector2Array([Vector2(-2.94508, -10.43825), Vector2(-3.12751, -10.31196), Vector2(-2.53344, -9.54482), Vector2(-2.94508, -10.43825)]),
		# g335
		PackedVector2Array([Vector2(4.62087, 2.61543), Vector2(4.07793, 3.34106), Vector2(4.16180, 3.40219), Vector2(4.72679, 2.69222), Vector2(4.62087, 2.61543)]),
		# g336
		PackedVector2Array([Vector2(5.29287, 3.24239), Vector2(4.78988, 3.90188), Vector2(4.87371, 3.95776), Vector2(5.26493, 3.74539), Vector2(5.29287, 3.24239)]),
		# g469
		PackedVector2Array([Vector2(-3.87378, 7.18748), Vector2(-4.18962, 7.13612), Vector2(-2.90971, 10.17850), Vector2(-2.74706, 9.96419), Vector2(-3.87378, 7.18748)]),
		# g470
		PackedVector2Array([Vector2(2.74706, 9.96419), Vector2(2.90971, 10.17850), Vector2(4.18962, 7.13612), Vector2(3.87378, 7.18748), Vector2(2.74706, 9.96419)]),
		# g471
		PackedVector2Array([Vector2(3.16337, -2.56358), Vector2(4.26675, -4.86628), Vector2(3.99089, -4.92223), Vector2(3.78702, -4.20266), Vector2(3.43522, -3.45907), Vector2(3.04344, -2.68351), Vector2(3.16337, -2.56358)]),
		# g472
		PackedVector2Array([Vector2(-5.52126, -3.05622), Vector2(-3.23288, -1.74847), Vector2(-3.14122, -2.05115), Vector2(-4.92744, -3.00122), Vector2(-5.38352, -3.24689), Vector2(-5.52126, -3.05622)]),
	]
	return polylines


## Both flippers. The original stores a pivot plus the TIP POSITION at each end
## of the swing; the angles below are worked out from those, which is why they
## are not round numbers.
static func flipper_mounts() -> Array[Dictionary]:
	return [
		{
			"name": "FlipperLeft",
			"pivot": Vector2(-2.48882, 12.06306),
			"input_action": &"wasd_left",
			"mirrored": false,
			"length": 1.86378,
			"rest_angle_deg": 34.9580,
			"up_angle_deg": -34.6695,
		},
		{
			"name": "FlipperRight",
			"pivot": Vector2(2.48882, 12.06306),
			"input_action": &"wasd_right",
			"mirrored": true,
			"length": 1.86378,
			"rest_angle_deg": 34.9580,
			"up_angle_deg": -34.6695,
		},
	]


## Seven bumpers, not three. Three of them are larger and sit up the table,
## three smaller ones sit together on the right, and one sits alone at the top.
## Radii differ, so this returns a radius per bumper rather than one constant.
static func bumper_spots() -> Array[Dictionary]:
	var spots: Array[Dictionary] = [
		{"pos": Vector2(-0.00800, -3.72000), "radius": 0.3500},
		{"pos": Vector2(1.37752, -6.61803), "radius": 0.3500},
		{"pos": Vector2(-1.25106, -5.96048), "radius": 0.3500},
		{"pos": Vector2(-5.76945, -10.95512), "radius": 0.3500},
		{"pos": Vector2(-5.28000, 4.00000), "radius": 0.2500},
		{"pos": Vector2(-7.14000, 3.50000), "radius": 0.2500},
		{"pos": Vector2(-6.45129, 4.90790), "radius": 0.2500},
	]
	return spots


## Where the ball waits for the plunger: at the foot of the launch lane, which
## the original puts on the RIGHT-hand side.
static func ball_spawn() -> Vector3:
	return Vector3(7.021, 0.0, 12.837)


## ── R2 的机关 ────────────────────────────────────────────────────────
## 全部来自原版数据。用户看过原作后砍掉了红靶 13 个（偏右侧与下方）、单向门、
## 门、trip、旗帜与坡道，只留下"玩家能感觉到存在"的这几类。

## 黄靶：原版是一根细长条，撞了就倒（缩下去）并计分。
static func yellow_targets() -> Array[PackedVector2Array]:
	var items: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(4.24204, 0.70673), Vector2(4.15796, 0.70671), Vector2(4.15796, 1.22286), Vector2(4.24204, 1.22289)]),
		PackedVector2Array([Vector2(4.24204, 1.40808), Vector2(4.15796, 1.40805), Vector2(4.15796, 1.92420), Vector2(4.24204, 1.92423)]),
		PackedVector2Array([Vector2(4.24204, 2.10673), Vector2(4.15796, 2.10671), Vector2(4.15796, 2.62286), Vector2(4.24204, 2.62289)]),
		PackedVector2Array([Vector2(-1.28448, -2.87833), Vector2(-1.31213, -2.79892), Vector2(-0.82463, -2.62934), Vector2(-0.79698, -2.70874)]),
		PackedVector2Array([Vector2(-0.62208, -2.64790), Vector2(-0.64972, -2.56849), Vector2(-0.16222, -2.39891), Vector2(-0.13458, -2.47831)]),
		PackedVector2Array([Vector2(0.03780, -2.41836), Vector2(0.01015, -2.33895), Vector2(0.49765, -2.16936), Vector2(0.52530, -2.24877)]),
		PackedVector2Array([Vector2(-3.36917, -7.92445), Vector2(-3.32464, -7.85313), Vector2(-2.88692, -8.12665), Vector2(-2.93145, -8.19797)]),
		PackedVector2Array([Vector2(-2.77440, -8.29610), Vector2(-2.72987, -8.22479), Vector2(-2.29214, -8.49831), Vector2(-2.33668, -8.56963)]),
		PackedVector2Array([Vector2(-2.18191, -8.66633), Vector2(-2.13737, -8.59502), Vector2(-1.69965, -8.86854), Vector2(-1.74419, -8.93985)]),
	]
	return items

## 洞：球进去、停一下、再弹回来。原版存的是圆心 + 半径。
static func sink_spots() -> Array[Dictionary]:
	var items: Array[Dictionary] = [
		{"pos": Vector2(2.61827, -8.82871), "radius": 0.1438},
		{"pos": Vector2(-3.17189, -9.75720), "radius": 0.1272},
		{"pos": Vector2(4.71443, 3.32902), "radius": 0.1438},
		{"pos": Vector2(7.06160, -1.56909), "radius": 0.1438},
	]
	return items

## kicker：一条横线，球碰上就被踢出去。
static func kickers() -> Array[PackedVector2Array]:
	var items: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-6.35641, 11.76075), Vector2(-7.65540, 11.76075)]),
		PackedVector2Array([Vector2(6.36669, 11.76926), Vector2(5.16775, 11.76926)]),
	]
	return items
## 滚过开关：没有实体，球从上面滚过去就计分亮灯。
## "球到底有没有掠过这个矩形"是每帧算的，不用碰撞体——高速球会一步跨过 Area。
static func rollovers() -> Array[PackedVector2Array]:
	var items: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-1.70535, -9.16052), Vector2(-0.79465, -9.16052), Vector2(-0.79465, -9.83948), Vector2(-1.70535, -9.83948)]),
		PackedVector2Array([Vector2(-0.46099, -9.16965), Vector2(0.46099, -9.16965), Vector2(0.46099, -9.83035), Vector2(-0.46099, -9.83035)]),
		PackedVector2Array([Vector2(0.82961, -9.15194), Vector2(1.67039, -9.15194), Vector2(1.67039, -9.84806), Vector2(0.82961, -9.84806)]),
		PackedVector2Array([Vector2(-7.43762, 8.33930), Vector2(-6.56238, 8.33930), Vector2(-6.56238, 7.66070), Vector2(-7.43762, 7.66070)]),
		PackedVector2Array([Vector2(-6.20368, 8.30467), Vector2(-5.49632, 8.30467), Vector2(-5.49632, 7.69533), Vector2(-6.20368, 7.69533)]),
		PackedVector2Array([Vector2(-5.17344, 8.35166), Vector2(-4.32656, 8.35166), Vector2(-4.32656, 7.64834), Vector2(-5.17344, 7.64834)]),
		PackedVector2Array([Vector2(4.34468, 8.35476), Vector2(5.15532, 8.35476), Vector2(5.15532, 7.64524), Vector2(4.34468, 7.64524)]),
		PackedVector2Array([Vector2(5.49249, 8.34682), Vector2(6.20751, 8.34682), Vector2(6.20751, 7.65318), Vector2(5.49249, 7.65318)]),
		PackedVector2Array([Vector2(-7.52724, 2.09155), Vector2(-7.00779, 2.09155), Vector2(-7.00779, 1.60388), Vector2(-7.52724, 1.60388)]),
		PackedVector2Array([Vector2(-6.66445, 2.33445), Vector2(-5.97423, 2.33445), Vector2(-5.97423, 1.85627), Vector2(-6.66445, 1.85627)]),
		PackedVector2Array([Vector2(-5.69430, 2.63240), Vector2(-5.01683, 2.63240), Vector2(-5.01683, 2.14883), Vector2(-5.69430, 2.14883)]),
		PackedVector2Array([Vector2(-4.69818, -7.00274), Vector2(-4.70907, -7.40554), Vector2(-5.06363, -7.59751), Vector2(-5.40728, -7.38668), Vector2(-5.39639, -6.98388), Vector2(-5.04184, -6.79192)]),
		PackedVector2Array([Vector2(-5.29872, 1.60950), Vector2(-4.94674, 2.06096), Vector2(-3.24425, 1.28562), Vector2(-3.57136, 0.84843)]),
		PackedVector2Array([Vector2(-5.71652, 0.64214), Vector2(-5.41018, 1.16249), Vector2(-4.11484, 0.34019), Vector2(-4.40065, -0.16329)]),
		PackedVector2Array([Vector2(-6.29373, -0.35932), Vector2(-5.97593, 0.24283), Vector2(-4.78758, -0.53092), Vector2(-5.08500, -1.11249)]),
		PackedVector2Array([Vector2(-6.72897, -1.37355), Vector2(-6.44602, -0.90404), Vector2(-5.43247, -1.42294), Vector2(-5.69755, -1.87590)]),
		PackedVector2Array([Vector2(-7.22756, -2.51240), Vector2(-6.94928, -2.04918), Vector2(-5.83214, -2.34569), Vector2(-6.09213, -2.79130)]),
		PackedVector2Array([Vector2(-7.41650, -3.52889), Vector2(-7.22569, -3.04214), Vector2(-6.26373, -3.29159), Vector2(-6.44084, -3.75946)]),
	]
	return items


