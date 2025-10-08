//-------------------------------------------------------------
//-- PCB Snap-In Mount Plate (v7)
//-- Correct inner lip cutout + inward slope
//-------------------------------------------------------------

//-- ===== Parameters (mm) =====
pcbWidth        = 30.5;
pcbLength       = 31.0;
pcbThickness    = 1.6 + 0.3;  //-- PCB thickness + Tolerance
pcbClearance    = 0.5;        //-- small fit tolerance, adjust if PCB feels too tight

snapInThickness = 3;          //-- XY thickness of wall
snapInHeight    = 12;         //-- Z height above plate
snapInSlope     = 60;         //-- degrees, 30..60 typical
snapInWidth     = 4;          //-- width of each snap along edge
snapInFilletRadius = 2;       //-- radius of rounded transition at base

//-- Snap-in positions (0 disables)
snapInPosTop    = pcbWidth  / 2;
snapInPosBottom = pcbWidth  / 2;
snapInPosLeft   = 8; //pcbLength / 2;
snapInPosRight  = pcbLength / 2;

plateThickness  = 2;
plateHolesList = [
    [pcbWidth/5, pcbLength/2, 4],
    [pcbWidth-(pcbWidth/4), pcbLength/2, 4],
    [pcbWidth/2, pcbLength/2, 8],
    [8, 5, 8],
    [pcbLength-8, 5, 8],
    [8, pcbWidth-5, 8],
    [pcbLength-8, pcbWidth-5, 8]
];

showDebug = 0;                //-- 1 = debug colors, 0 = final solid

//-------------------------------------------------------------
//-- Helpers
//-------------------------------------------------------------
function clamp(v,a,b) = max(a, min(b, v));
function drop_at_angle(thk, ang_deg, max_drop) = clamp(tan(ang_deg) * thk, 0, max_drop);

//-------------------------------------------------------------
//-- Green cutter: starts LOWER at inner face (H - D)
//-- and reaches H at the outer face, so it always cuts the wall
//-- Inner top aligns with lip top, outer top calculated from slope angle
//-------------------------------------------------------------
module cutSlopeAtTop(runLen)
{
    T = snapInThickness;
    lipZ = snapInHeight - (3.2 * pcbThickness);
    lipHeight = pcbThickness * 1.1;
    innerTop = lipZ + lipHeight;                     //-- inner top aligns with lip top
    D = T * tan(snapInSlope);                        //-- drop based on thickness and angle
    H = innerTop + D;                                 //-- outer top height
    eps = 0.01;                                       //-- tiny overlap for robust CSG

    //-- Inner top is at innerTop; outer top is at H.
    //-- We extend upwards a lot so the difference always removes material.
    v = [
        [-runLen/2, 0, innerTop - eps],   // 0 inner top (X-)
        [ runLen/2, 0, innerTop - eps],   // 1 inner top (X+)
        [-runLen/2, T, H + eps],          // 2 outer top (X-)
        [ runLen/2, T, H + eps],          // 3 outer top (X+)
        [-runLen/2, 0, innerTop + H],     // 4 top extension
        [ runLen/2, 0, innerTop + H],     // 5
        [-runLen/2, T, H + H],            // 6
        [ runLen/2, T, H + H]             // 7
    ];

    faces = [
        [0,1,3,2],   //-- sloped rectangle (cutting plane)
        [2,3,7,6],   //-- outer vertical
        [0,4,5,1],   //-- inner vertical
        [0,2,6,4],   //-- side (X-)
        [1,5,7,3],   //-- side (X+)
        [4,6,7,5]    //-- top
    ];

    color([0,1,0,0.5]) polyhedron(points = v, faces = faces, convexity = 10);
}

//-------------------------------------------------------------
//-- Blue lip CUTTER: creates notch *inside* wall for PCB edge
//-------------------------------------------------------------
module lipCutter(runLen)
{
    clearance = pcbClearance;                //-- fit clearance
    lipDepth  = pcbThickness * 0.9;          //-- how deep the notch goes inward
    lipHeight = pcbThickness * 1.1;          //-- vertical size of notch
    lipZ      = snapInHeight - (3.2 * pcbThickness); //-- fixed position from top

    color("blue")
    translate([ -runLen/2, 0, lipZ ])        //-- cut starts at wall inner face (Y=0)
        cube([ runLen, lipDepth, lipHeight ]);
}

//-------------------------------------------------------------
//-- Red wall with rounded fillet transition at base (inner side)
//-- Adds material at inside corner where wall meets plate
//-------------------------------------------------------------
module wallBlockWithFillet(runLen)
{
  r = snapInFilletRadius;
  
  //-- Calculate wall height based on slope
  T = snapInThickness;
  lipZ = snapInHeight - (3.2 * pcbThickness);
  lipHeight = pcbThickness * 1.1;
  innerTop = lipZ + lipHeight;
  D = T * tan(snapInSlope);
  H = innerTop + D;  //-- actual outer top height
  
  color("red")
  union()
  {
    //-- Main wall block (height = outer top)
    translate([ -runLen/2, 0, 0 ])
      cube([ runLen, snapInThickness, H ]);
    
    //-- Fillet material at inner bottom corner (quarter-round profile)
    //-- Square block with center at r/2 inward from wall, circle at top-inner corner
    translate([ -runLen/2, -r, 0 ])
      difference()
      {
        //-- Green square block extending inward from wall
        color("green")
        cube([ runLen, r, r ]);
        
        //-- Purple circle at top-inner corner of square to create fillet radius
        color("purple")
        translate([ -0.1, 0, r ])
          rotate([0, 90, 0])
            cylinder(h = runLen + 0.2, r = r, $fn = 60);
      }
  }
}

//-------------------------------------------------------------
//-- Full Snap-In Mount
//-------------------------------------------------------------
module snapInMount(runLen)
{
    if (showDebug)
    {
        wallBlockWithFillet(runLen);
        cutSlopeAtTop(runLen);
        lipCutter(runLen);
    }
    else
    {
        difference()
        {
            wallBlockWithFillet(runLen);
            cutSlopeAtTop(runLen);
            lipCutter(runLen);
        }
    }
}

//-------------------------------------------------------------
//-- Snap placement helpers (with inward offset)
//-- Positions each snap so that its inner wall face overlaps
//-- the PCB edge by half the wall thickness.
//-------------------------------------------------------------

module placeTop(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: center position along width
            clamp(pos, runLen/2, pcbWidth - runLen/2) - pcbWidth/2,

            //-- Y: inward offset from top edge + clearance
            (pcbLength / 2 + pcbClearance) - (snapInThickness / 2),

            //-- Z: on top of the base plate
            plateThickness
        ])
            snapInMount(runLen);
}

module placeBottom(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: center position along width
            clamp(pos, runLen/2, pcbWidth - runLen/2) - pcbWidth/2,

            //-- Y: inward offset from bottom edge - clearance
            (-pcbLength / 2 - pcbClearance) + (snapInThickness / 2),

            //-- Z: on top of the base plate
            plateThickness
        ])
            rotate([0, 0, 180])
                snapInMount(runLen);
}

module placeLeft(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: inward offset from left edge - clearance
            (-pcbWidth / 2 - pcbClearance) + (snapInThickness / 2),

            //-- Y: center position along length
            clamp(pos, runLen/2, pcbLength - runLen/2) - pcbLength/2,

            //-- Z: on top of the base plate
            plateThickness
        ])
            rotate([0, 0, 90])
                snapInMount(runLen);
}

module placeRight(pos, runLen)
{
    if (pos != 0)
        translate([
            //-- X: inward offset from right edge + clearance
            (pcbWidth / 2 + pcbClearance) - (snapInThickness / 2),

            //-- Y: center position along length
            clamp(pos, runLen/2, pcbLength - runLen/2) - pcbLength/2,

            //-- Z: on top of the base plate
            plateThickness
        ])
            rotate([0, 0, -90])
                snapInMount(runLen);
}

//-------------------------------------------------------------
//-- Plate hole generator (generic version)
//-- Loops through all entries in plateHolesList = [ [x,y,d], ... ]
//-- and subtracts holes if both X and Y ≠ 0
//-------------------------------------------------------------
module plateHoles(pWidth, pLength, pThickness)
{
    difference()
    {
        //-- Base plate
        color("gold")
        translate([ -pWidth/2, -pLength/2, 0 ])
            cube([ pWidth, pLength, pThickness ]);

        //-- All defined holes
        for (hole = plateHolesList)
        {
            x = hole[0];
            y = hole[1];
            d = hole[2];

            if (!(x == 0 && y == 0))
            {
                translate([ x - pcbWidth/2, y - pcbLength/2, -0.1 ])
                    cylinder(h = pThickness + 0.2, d = d, $fn = 40);
            }
        }
    }
}

//-------------------------------------------------------------
//-- Main Assembly
//-------------------------------------------------------------
module pcbSnapInPlate()
{
    plateWidth  = pcbWidth  + 2*pcbClearance + snapInThickness;
    plateLength = pcbLength + 2*pcbClearance + snapInThickness;

    //-- Base plate with optional holes (correct thickness!)
    plateHoles(plateWidth, plateLength, plateThickness);

    //-- Mounts (sit exactly on top of the plate)
    placeTop(   snapInPosTop,    min(snapInWidth, pcbWidth)  );
    placeBottom(snapInPosBottom, min(snapInWidth, pcbWidth)  );
    placeLeft(  snapInPosLeft,   min(snapInWidth, pcbLength) );
    placeRight( snapInPosRight,  min(snapInWidth, pcbLength) );
}

//-------------------------------------------------------------
//-- Render
//-------------------------------------------------------------
pcbSnapInPlate();

//-------------------------------------------------------------
//-- Reference PCB block (black)
//-------------------------------------------------------------
lipZ = snapInHeight - (2.5 * pcbThickness);  //-- slightly less deep cut
translate([0, 0, plateThickness + lipZ - 0.2])
{
    ;//color([0,0,0,0.5])  cube([pcbWidth, pcbLength, pcbThickness], center=true);
}
