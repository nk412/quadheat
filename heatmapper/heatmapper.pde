//configurable options
String image_path="antarctica-map.gif";
int grid_nx=10;
int grid_ny=10;
boolean draw_grid = true;

//global vars
PImage map;


//========================================

void draw_gridlines(){
  if ( draw_grid == true ){
    int grid_w = round( map.width / grid_nx );
    int grid_h = round( map.height / grid_ny );
    for(int x = 0 ; x < grid_nx ; x++)
        line(x*grid_w,0,x*grid_w,map.height);
    for(int y = 0 ; y < grid_ny ; y++)
        line(0,y*grid_h,map.width,y*grid_h);
    }
}

void setup(){
  map=loadImage(image_path);
  size(map.width,map.height);
  draw_gridlines();
}

void draw(){
  background(map);
  line(10,10,30,30);
  draw_gridlines();
}
