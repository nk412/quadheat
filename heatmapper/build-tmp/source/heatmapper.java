import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import controlP5.*; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class heatmapper extends PApplet {


ControlP5 cp5;

//Global vars
String image_path = "mass_effect.jpg";
String data_file  = "heatmap_data.tsv";
float scaling_factor = 0.7f;
int cp5_panel_offset = 300;
int MAX_BINS=40;
PImage map;
Slider2D gridsize_selector;
String[] raw_dataset;
int grid_w, grid_h;

//Control panel settings
float max_fps_threshold = 30;
float min_obs_threshold = 10;
boolean directional_mode = false;
boolean enable_gridlines = false;
boolean show_fps = true;
boolean show_obs = false;
int grid_nx=15;
int grid_ny=10;

//Santa_Veiva specific settings
float x_offset = 8;
float y_offset = 232;
float orig_w = 900; 
float orig_h = 536;

//Grid settings
float grid_stroke=0.1f;
float square_opacity=180;

//Data container
float[][][][] heatmap_data =  new float[4][MAX_BINS][MAX_BINS][2];

//=================================================================================


// Coordinate translation
public float translate_x_coord(float x){
  return ( (x - x_offset)/orig_w ) * map.width;
}
public float translate_y_coord(float y){
  float fixed_y = ( (y - y_offset)/orig_h ) * map.height;
  return map.height - fixed_y;
}

public float translate_fps(float old_fps){
  return max(0,60-old_fps);
}

public float round_float(float val, int dp)
{
  return PApplet.parseInt(val*pow(10,dp))/pow(10,dp);
} 

public String generate_intext(float val, float obs){
    String intext = "";
    if( show_fps == true ) intext+=round_float(60-val,1);
    if( show_obs == true ) intext+="("+PApplet.parseInt(obs)+")";
    return intext;
}

public int get_direction( String rot ){
  // N,E,S,W = 0,1,2,3
  float u = PApplet.parseFloat ( split (rot,",")[0] );
  float v = PApplet.parseFloat ( split (rot,",")[1] );
  float w = PApplet.parseFloat ( split (rot,",")[2] );
  if ( v < 45 || v > 315 ) return 0;
  else if ( v < 135 ) return 1;
  else if ( v < 225 ) return 2;
  else return 3;
}

public void update_heatmap_data(int binx, int biny, int dir, float old_fps){
  //update count and mean
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

public void parse_line(String l){
  String pos = split(l,TAB)[0];
  String rot = split(l,TAB)[1];
  String fps = split(l,TAB)[2];

  float pos_x = translate_x_coord(    PApplet.parseFloat(split(pos,',')[0])    );
  float pos_y = translate_y_coord(    PApplet.parseFloat(split(pos,',')[2])    );

  int direction = get_direction(rot);

  int binx = max(0, floor( pos_x / grid_w ));
  int biny = max(0, floor( pos_y / grid_h));
  binx = min(grid_nx-1,binx);
  biny = min(grid_ny-1,biny);

  update_heatmap_data(binx,biny,direction,PApplet.parseFloat(fps));

  // println(direction, pos_x, pos_y);
}



public void read_dataset(){
  for (int l = 0 ; l<raw_dataset.length ; l++ )
    parse_line(raw_dataset[l]);
}

public void reset_array(){
  for ( int dir = 0 ; dir < 4 ; dir++ )
    for ( int x = 0 ; x < MAX_BINS ; x++ )
      for ( int y = 0 ;  y < MAX_BINS ; y++ ){
        heatmap_data[dir][x][y][0]=0;
        heatmap_data[dir][x][y][1]=0;
      }
}

public void print_dataset(){
  for ( int x=0; x<grid_nx; x++ ){
    for ( int y=0 ; y< grid_ny; y++){
      for ( int dir = 0; dir<1; dir++){
        print(heatmap_data[dir][x][y][0]+" ");
        }
      }
    println("");
  }  
}



public void draw_gridlines(){
  if ( enable_gridlines == true ){
    for(int x = 0 ; x < grid_nx ; x++)
        line(x*grid_w,0,x*grid_w,map.height);
    for(int y = 0 ; y < grid_ny ; y++)
        line(0,y*grid_h,map.width,y*grid_h);
    }
}

public void draw_triangles(){

  //calculate maxes for opacity
  float maxes[] = new float[4];
  float mins[] = new float[4];
  maxes[0]=0;  maxes[1]=0;  maxes[2]=0;  maxes[3]=0; //set to init value
  mins[0]=100;  mins[1]=100;  mins[2]=100;  mins[3]=100; // set to init value
  for(int dir=0; dir<4; dir++) for(int x=0;x<grid_nx;x++) for(int y=0;y<grid_ny;y++){
    if (heatmap_data[dir][x][y][0] > maxes[dir]) maxes[dir]=heatmap_data[dir][x][y][0];
    if (heatmap_data[dir][x][y][0] < mins[dir] && heatmap_data[dir][x][y][0] != 0 ) mins[dir]=heatmap_data[dir][x][y][0];
  }

  for (int x=0; x<grid_nx; x++) for (int y=0; y< grid_ny; y++) for (int dir=0; dir<4; dir++){
    int tl_x = x * grid_w;
    int tl_y = y * grid_h;

    float val = heatmap_data[dir][x][y][0];
    if ( 60 - val > max_fps_threshold ) continue;
    
    float obs = heatmap_data[dir][x][y][1];
    if ( obs < min_obs_threshold ) continue;      
            
    
    float mx = maxes[dir];
    float mn = mins[dir];
    float strength=max(0,(val-mn)/(mx-mn));
          
    float opac = floor(strength*square_opacity);
    if (opac == 0) continue;


    String intext = generate_intext(val,obs);

    
    switch(dir){
      case 0: // north
        fill(255,0,0,opac); triangle(tl_x,tl_y,               tl_x+grid_w,tl_y,                tl_x+(grid_w/2),tl_y+(grid_h/2));
        fill(255); text( intext,  tl_x+(grid_w/3), tl_y+(grid_h/4));
        break;
        
      case 1: // east
        fill(255,0,0,opac); triangle(tl_x+grid_w,tl_y,        tl_x+grid_w,tl_y+grid_h,         tl_x+(grid_w/2),tl_y+(grid_h/2));
        fill(255); text( intext,  tl_x+(grid_w/2), tl_y+(grid_h/2));
        break;
     
      case 2: // south
        fill(255,0,0,opac); triangle(tl_x+grid_w,tl_y+grid_h, tl_x,tl_y+grid_h,                tl_x+(grid_w/2),tl_y+(grid_h/2));
        fill(255); text( intext,  tl_x+(grid_w/3), tl_y+grid_h);
        break;
      
      case 3: // west
        fill(255,0,0,opac); triangle(tl_x,tl_y,               tl_x,tl_y+grid_h,                tl_x+(grid_w/2),tl_y+(grid_h/2));
        fill(255); text( intext,  tl_x, tl_y+(grid_h/2));
        break;
     }
  }
}

public void draw_boxes(){

  //calculate maxes for opacity
  float max_single = 0; // set to init value
  float min_single = 100; // set to init value
  
  for(int dir=0; dir<4; dir++) for(int x=0;x<grid_nx;x++) for(int y=0;y<grid_ny;y++){
    if (heatmap_data[dir][x][y][0] > max_single ) max_single=heatmap_data[dir][x][y][0];
    if (heatmap_data[dir][x][y][0] < min_single && heatmap_data[dir][x][y][0] != 0 ) min_single=heatmap_data[dir][x][y][0];
  }

  for (int x=0; x<grid_nx; x++) for (int y=0; y< grid_ny; y++){
    int tl_x = x * grid_w;
    int tl_y = y * grid_h;

    float compound_val = 0;
    float compound_obs = 0;
    for (int dir=0; dir<4; dir++){
      compound_val += heatmap_data[dir][x][y][0] * heatmap_data[dir][x][y][1];
      compound_obs += heatmap_data[dir][x][y][1];
    }
    float val = compound_val / compound_obs ;
    if ( 60 - val > max_fps_threshold ) continue;
    float obs = compound_obs;
    if ( obs < min_obs_threshold ) continue;      
            
    float strength=max(0,(val-min_single)/(max_single - min_single));
          
    float opac = floor(strength*square_opacity);
    if (opac == 0) continue;

    String intext = generate_intext(val,obs);

    rectMode(CORNERS);
    fill(255,0,0,opac); rect(tl_x,tl_y,tl_x+grid_w,tl_y+grid_h);
    fill(255); text( intext,  tl_x+(grid_w/3), tl_y+(grid_h/2));
  }
}

public void draw_heatmap(){
  if ( directional_mode == true )   draw_triangles();
  else                              draw_boxes();
}


public void setup(){
  
  println("Loading image...");
  map=loadImage(image_path);
  raw_dataset = loadStrings(data_file);

  map.resize( PApplet.parseInt(map.width*scaling_factor) , PApplet.parseInt(map.height*scaling_factor) );
  size(map.width,map.height);

  // set global variables 
  strokeWeight(grid_stroke);
  textSize(10);
  stroke(255,100);
  

  //cp5 control panel
  cp5 = new ControlP5(this);
  cp5.addSlider("max_fps_threshold").setPosition(width - cp5_panel_offset,25).setSize(200,20).setRange(0,60).setValue(25);
  cp5.addSlider("min_obs_threshold").setPosition(width - cp5_panel_offset,50).setSize(200,20).setRange(0,1000).setValue(200);
  cp5.addToggle("directional_mode").setPosition(width - cp5_panel_offset + 120 ,75).setSize(30,20);
  cp5.addToggle("enable_gridlines").setPosition(width -cp5_panel_offset + 120,110).setSize(30,20);
  cp5.addToggle("show_fps").setPosition(width - cp5_panel_offset + 220 ,75).setSize(30,20);
  cp5.addToggle("show_obs").setPosition(width -cp5_panel_offset + 220,110).setSize(30,20);
  gridsize_selector=cp5.addSlider2D("gridsize").setPosition(width - cp5_panel_offset,75).setSize(100,100).setArrayValue(new float[] {70, 81});
  
  // refresh_data();
}

public void refresh_data(){
  grid_nx = max( 1, min(MAX_BINS, PApplet.parseInt( (100 - gridsize_selector.arrayValue()[0]) / 2.2f) ) );
  grid_ny = max( 1, min(MAX_BINS, PApplet.parseInt( (100 - gridsize_selector.arrayValue()[1]) / 2.2f ) ) );
  grid_w = round( map.width / grid_nx );
  grid_h = round( map.height / grid_ny );
  reset_array();
  read_dataset();
}

public void draw(){
  background(map);
  refresh_data();
  draw_gridlines();
  fill(0,0,0,150);
  rect(width-cp5_panel_offset - 20,0,width+20,200,7);
  draw_heatmap();
}
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "heatmapper" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
