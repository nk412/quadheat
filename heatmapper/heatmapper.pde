import controlP5.*;
ControlP5 cp5;

//CONFIG
//TODO move this out to a file

//Global vars
String image_path = "santa_veiva.jpg";
String data_file  = "heatmap_data.tsv";
PImage map;
int grid_w, grid_h;
float slider_show_fps_under = 60;
float slider_show_min_obs = 10;

//Data source settings
float x_offset = 8;
float y_offset = 232;
float orig_w = 900; 
float orig_h = 536;

//Grid settings
int grid_nx=13;
int grid_ny=10;
boolean draw_grid = false;
float grid_stroke=0.1;
float square_opacity=255;


float[][][][] heatmap_data =  new float[4][grid_nx][grid_ny][2];
// direction, xbin, ybin, level (val/count)

//=================================================================================


// Coordinate translation
float translate_x_coord(float x){
  return ( (x - x_offset)/orig_w ) * map.width;
}
float translate_y_coord(float y){
  float fixed_y = ( (y - y_offset)/orig_h ) * map.height;
  return map.height - fixed_y;
}

float translate_fps(float old_fps){
  return max(0,60-old_fps);
}

float round_float(float val, int dp)
{
  return int(val*pow(10,dp))/pow(10,dp);
} 
int get_direction( String rot ){
  // N,E,S,W = 0,1,2,3
  float u = float ( split (rot,",")[0] );
  float v = float ( split (rot,",")[1] );
  float w = float ( split (rot,",")[2] );
  if ( v < 45 || v > 315 ) return 0;
  else if ( v < 135 ) return 1;
  else if ( v < 225 ) return 2;
  else return 3;
}

void update_heatmap_data(int binx, int biny, int dir, float old_fps){
  //update count and mean
//  println(binx,biny,dir,fps);
  if ( old_fps == 0 ) return; 
  float fps = translate_fps(old_fps);
  float old_val = heatmap_data[dir][binx][biny][0];
  float old_cnt = heatmap_data[dir][binx][biny][1];
  float old_prod = old_val * old_cnt;
  old_prod += fps;
  old_cnt += 1;
  float new_val = old_prod / old_cnt;
  heatmap_data[dir][binx][biny][0] = new_val;
  heatmap_data[dir][binx][biny][1] = old_cnt;
}

void parse_line(String l){
  String pos = split(l,TAB)[0];
  String rot = split(l,TAB)[1];
  String fps = split(l,TAB)[2];

  float pos_x = translate_x_coord(    float(split(pos,',')[0])    );
  float pos_y = translate_y_coord(    float(split(pos,',')[2])    );

  int direction = get_direction(rot);

  int binx = max(0, floor( pos_x / grid_w ));
  int biny = max(0, floor( pos_y / grid_h));
  binx = min(grid_nx-1,binx);
  biny = min(grid_ny-1,biny);

  update_heatmap_data(binx,biny,direction,float(fps));

  // println(direction, pos_x, pos_y);
}



void read_dataset(){
  print("Processing dataset...");
  String[] dataset = loadStrings(data_file);
  for (int l = 0 ; l<dataset.length ; l++ )
    parse_line(dataset[l]);
  println("Done!");
}

void init_array(){
  for ( int dir = 0 ; dir < 4 ; dir++ )
    for ( int x = 0 ; x < grid_nx ; x++ )
      for ( int y = 0 ;  y < grid_ny ; y++ ){
        heatmap_data[dir][x][y][0]=0;
        heatmap_data[dir][x][y][1]=0;
      }
}

void print_dataset(){
  for ( int x=0; x<grid_nx; x++ ){
    for ( int y=0 ; y< grid_ny; y++){
      for ( int dir = 0; dir<1; dir++){
        print(heatmap_data[dir][x][y][0]+" ");
        }
      }
    println("");
  }  
}



void draw_gridlines(){
  if ( draw_grid == true ){
    for(int x = 0 ; x < grid_nx ; x++)
        line(x*grid_w,0,x*grid_w,map.height);
    for(int y = 0 ; y < grid_ny ; y++)
        line(0,y*grid_h,map.width,y*grid_h);
    }
}

void draw_triangles(){

  //calculate maxes for opacity
  float maxes[] = new float[4];
  float mins[] = new float[4];
  maxes[0]=0;  maxes[1]=0;  maxes[2]=0;  maxes[3]=0;
  mins[0]=100;  mins[1]=100;  mins[2]=100;  mins[3]=100;

  for(int dir=0; dir<4; dir++)
    for(int x=0;x<grid_nx;x++)
      for(int y=0;y<grid_ny;y++){
        if (heatmap_data[dir][x][y][0] > maxes[dir]) maxes[dir]=heatmap_data[dir][x][y][0];
        if (heatmap_data[dir][x][y][0] < mins[dir] && heatmap_data[dir][x][y][0] != 0 ) mins[dir]=heatmap_data[dir][x][y][0];
      }


  for ( int x=0; x<grid_nx; x++ ){
    for ( int y=0 ; y< grid_ny; y++){
      for ( int dir = 0; dir<4; dir++){
        int tl_x = x * grid_w;
        int tl_y = y * grid_h;

        float val = heatmap_data[dir][x][y][0];
        if ( 60 - val > slider_show_fps_under ) continue;
        
        float obs = heatmap_data[dir][x][y][1];
        if ( obs < slider_show_min_obs ) continue;      
                
        
        float mx = maxes[dir];
        float mn = mins[dir];
        float strength=max(0,(val-mn)/(mx-mn));
        float opac = floor(strength*square_opacity);
//        println("value:",val," max:",mx," min:",mn," strength:",strength," opac:",opac);
        if (opac == 0) continue;

        // if (opac > 0 ) println(opac);
        // println(val,mx, opac);

        switch(dir){
          case 0:
            fill(opac,0,0,100);  //NORTH
            triangle(tl_x,tl_y,               tl_x+grid_w,tl_y,                tl_x+(grid_w/2),tl_y+(grid_h/2));
            fill(255); text( round_float(60-val,1) +"("+int(obs)+")",  tl_x+(grid_w/3), tl_y+(grid_h/4));
            break;
            
          case 1:
//            fill(#9400d3,opac); //EAST
            fill(opac,0,0,100);
            triangle(tl_x+grid_w,tl_y,        tl_x+grid_w,tl_y+grid_h,         tl_x+(grid_w/2),tl_y+(grid_h/2));
            fill(255); text(  round_float(60-val,1) +"("+int(obs)+")",  tl_x+(grid_w/2), tl_y+(grid_h/2));
            break;
         
          case 2:
//            fill(#9400d3,opac); //SOUTH
            fill(opac,0,0,100);
            triangle(tl_x+grid_w,tl_y+grid_h, tl_x,tl_y+grid_h,                tl_x+(grid_w/2),tl_y+(grid_h/2));
            fill(255); text(  round_float(60-val,1) +"("+int(obs)+")",  tl_x+(grid_w/3), tl_y+grid_h);
            break;
          
          case 3:
//            fill(#9400d3,opac); //WEST
            fill(opac,0,0,100);
            triangle(tl_x,tl_y,               tl_x,tl_y+grid_h,                tl_x+(grid_w/2),tl_y+(grid_h/2));
            fill(255); text(  round_float(60-val,1) +"("+int(obs)+")",  tl_x, tl_y+(grid_h/2));
            break;
        }
        
      }
    }
  }
}

void setup(){
  
  println("Loading image...");
  map=loadImage(image_path);
  size(map.width,map.height);
  strokeWeight(grid_stroke);
  textSize(10);
  stroke(255,100);
  grid_w = round( map.width / grid_nx );
  grid_h = round( map.height / grid_ny );
  println("Initializing array...");
  init_array();
  println("Reading data...");
  read_dataset();
//  print_dataset();


  cp5 = new ControlP5(this);
  cp5.addSlider("slider_show_fps_under")
     .setPosition(1500,25)
     .setSize(200,20)
     .setRange(0,60)
     .setValue(25)
     ;
  cp5.addSlider("slider_show_min_obs")
     .setPosition(1500,50)
     .setSize(200,20)
     .setRange(0,5000)
     .setValue(2500)
     ;
}

void draw(){
  background(map);
//  println("Drawing gridlines...");
//  draw_gridlines();
//  println("Drawing triangles...");
  draw_triangles();
//  saveFrame("out.jpg");
//  delay(100000);
}
