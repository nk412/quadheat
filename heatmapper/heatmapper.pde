import controlP5.*;
import java.util.Properties;

ControlP5 cp5;
P5Properties props;
String config_file="conf.properties";

//MODE
boolean binned_input;
int input_grid_nx;
int input_grid_ny;
boolean aggregated_data;

//Global vars
String image_path;
String data_file;
float scaling_factor;
int MAX_BINS=100;
int heatmap_min;
int heatmap_max;
PImage map;
Slider2D gridsize_selector;
String[] raw_dataset;
int grid_w, grid_h;
float observed_min=0;
float observed_max=0;

//Control panel settings
int cp5_panel_offset = 300;
float max_fps_threshold = 30;
float min_obs_threshold = 10;
boolean directional_mode = false;
boolean enable_gridlines = true;
boolean show_fps = false;
boolean show_obs = false;
int grid_nx=15;
int grid_ny=10;
int old_grid_nx,old_grid_ny;
boolean override_optima=false;

//Map translation settings
float x_offset;
float y_offset;
float orig_w;
float orig_h;

//Grid settings
float grid_stroke=0.1;
float square_opacity=180;

//Data container
float[][][][] heatmap_data =  new float[4][MAX_BINS][MAX_BINS][2];

//=================================================================================

class P5Properties extends Properties {
  boolean getBooleanProperty(String id, boolean defState) {
    return boolean(getProperty(id,""+defState));
  }
  int getIntProperty(String id, int defVal) {
    return int(getProperty(id,""+defVal)); 
  }
  float getFloatProperty(String id, float defVal) {
    return float(getProperty(id,""+defVal)); 
  }  
};

// Coordinate translation
float translate_x_coord(float x){
  return ( (x - x_offset)/orig_w ) * map.width;
}
float translate_y_coord(float y){
  float fixed_y = ( (y - y_offset)/orig_h ) * map.height;
  return map.height - fixed_y;
}

float translate_fps(float old_fps){
  // return max(0,60-old_fps);
  return old_fps;

}

float round_float(float val, int dp)
{
  return int(val*pow(10,dp))/pow(10,dp);
} 

String generate_intext(float val, float obs){
    String intext = "";
    // if( show_fps == true ) intext+=round_float(60-val,1);
    if( show_fps == true ) intext+=round_float(val,1);
    if( show_obs == true ) intext+="\n("+int(obs)+")";
    return intext;
}

int get_direction( float rot ){
  // N,E,S,W = 0,1,2,3
  if ( rot < 45 || rot > 315 ) return 0;
  else if ( rot < 135 ) return 1;
  else if ( rot < 225 ) return 2;
  else return 3;
}

void update_heatmap_data(int binx, int biny, int dir, float old_fps, float obs){
  //update count and mean
  if ( old_fps == 0 ) return; 
  float fps = translate_fps(old_fps);
  float old_val = heatmap_data[dir][binx][biny][0]; //mean
  float old_cnt = heatmap_data[dir][binx][biny][1]; //count
  float old_prod = old_val * old_cnt;
  old_prod += fps;
  old_cnt += obs;
  float new_val = old_prod / old_cnt;
  heatmap_data[dir][binx][biny][0] = new_val;
  heatmap_data[dir][binx][biny][1] = old_cnt;

  // update recorded min and max
  if (new_val < observed_min) observed_min = new_val;
  if (new_val > observed_max) observed_max = new_val;

}

void update_heatmap_data_aggregated_data(int binx, int biny, int dir, float old_fps, float obs){
  //update count and mean
  float fps=translate_fps(old_fps);
  
  float old_val = heatmap_data[dir][binx][biny][0]; //mean
  float old_cnt = heatmap_data[dir][binx][biny][1]; //count
  float old_prod = old_val * old_cnt;
  old_prod += (fps*obs);
  old_cnt += obs;
  float new_val = old_prod / old_cnt;
  
  heatmap_data[dir][binx][biny][0] = new_val;
  heatmap_data[dir][binx][biny][1] = old_cnt;

    // update recorded min and max
  if (new_val < observed_min) observed_min = new_val;
  if (new_val > observed_max) observed_max = new_val;

}


void update_heatmap_data_binned_input(int binx, int biny, int dir, float old_fps, float obs){
  println(binx,biny,dir,old_fps,obs);
  //update count and mean
  if ( old_fps == 0 ) return;
  float fps = translate_fps(old_fps);
  
  heatmap_data[dir][binx][biny][0] = fps;
  heatmap_data[dir][binx][biny][1] = obs;

  // update recorded min and max
  if (fps < observed_min) observed_min = fps;
  if (fps > observed_max) observed_max = fps;
}

int bin_pos_x( float pos_x){
  int bin_x=0;
  if ( binned_input == false ){
    bin_x = max(0, floor( pos_x / grid_w ));
    bin_x = min(grid_nx-1,bin_x);
  } else {
    bin_x = int(  max(0, pos_x )  );
  }
  return bin_x;
}

int bin_pos_y( float pos_y){
  int bin_y=0;
  if ( binned_input == false ){
    bin_y = max(0, floor( pos_y / grid_h));
    bin_y = min(grid_ny-1,bin_y);
  } else {
    bin_y = int(  max(0, pos_y )  );
  }
  return bin_y;
}

void parse_line(String l){
  
  String[] columns = splitTokens(l,"\t");
  
  float pos_x = translate_x_coord( float(columns[0]) );
  float pos_y = translate_y_coord( float(columns[1]) );
  int direction = get_direction( float(columns[2]) );
  float fps = float(columns[3]);

  float obs = 1;
  if ( columns.length > 4 ) obs= int( columns[4] );

  int bin_x=bin_pos_x(pos_x);
  int bin_y=bin_pos_y(pos_y);

  if ( binned_input == true )
    update_heatmap_data_binned_input(bin_x,bin_y,direction,fps,obs);
  else if ( aggregated_data == true )
    update_heatmap_data_aggregated_data(bin_x,bin_y,direction,fps,obs);
  else
    update_heatmap_data(bin_x,bin_y,direction,fps,obs);                               
}



void read_dataset(){
  for (int l = 0 ; l<raw_dataset.length ; l++ )
    parse_line(raw_dataset[l]);
  cp5.getController("heatmap_min").setMin(observed_min);
  cp5.getController("heatmap_min").setMax(observed_max);
  cp5.getController("heatmap_max").setMin(observed_min);
  cp5.getController("heatmap_max").setMax(observed_max);
  cp5.getController("max_fps_threshold").setMin(observed_min);
  cp5.getController("max_fps_threshold").setMax(observed_max);
}

void reset_array(){
  for ( int dir = 0 ; dir < 4 ; dir++ )
    for ( int x = 0 ; x < MAX_BINS ; x++ )
      for ( int y = 0 ;  y < MAX_BINS ; y++ ){
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
  if ( enable_gridlines == true ){
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
    // if ( 60 - val > max_fps_threshold ) continue;
    
    float obs = heatmap_data[dir][x][y][1];
    if ( obs < min_obs_threshold ) continue;      
            
    
    float mx = maxes[dir];
    float mn = mins[dir];
    
    if ( override_optima == true ){
      mx=heatmap_max;
      mn=heatmap_min;
    }
    
    
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

void draw_boxes(){

  //calculate maxes for opacity
  float max_single = 0; // set to init value
  float min_single = 100; // set to init value
  
  for(int dir=0; dir<4; dir++) for(int x=0;x<grid_nx;x++) for(int y=0;y<grid_ny;y++){
    if (heatmap_data[dir][x][y][0] > max_single ) max_single=heatmap_data[dir][x][y][0];
    if (heatmap_data[dir][x][y][0] < min_single && heatmap_data[dir][x][y][0] != 0 ) min_single=heatmap_data[dir][x][y][0];
  }
  
  if ( override_optima == true ){
    max_single=heatmap_max;
    min_single=heatmap_min;
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
    float val = compound_val / compound_obs;
    if ( val > max_fps_threshold ) continue;
    float obs = compound_obs;
    if ( obs < min_obs_threshold ) continue;      
            
    float strength=max(0,(val-min_single)/(max_single - min_single));
          
    float opac = floor(strength*square_opacity);
    if (opac == 0) continue;

    String intext = generate_intext(val,obs);

    rectMode(CORNERS);
    fill(255,0,0,opac); rect(tl_x,tl_y,tl_x+grid_w,tl_y+grid_h);
    fill(255); text( intext,  tl_x+(grid_w/3), tl_y+(grid_h/2) );

  }
}

void draw_heatmap(){
  if ( directional_mode == true )
    draw_triangles();
  else
    draw_boxes();
}

void read_config_file(){
    try {
      props=new P5Properties();
      props.load(openStream(config_file));
   
      // all values returned by the getProperty() method are Strings
      // so we need to cast them into the appropriate type ourselves
      // this is done for us by the convenience P5Properties class below
      //MODE
            
      
      binned_input = props.getBooleanProperty("binned_mode.enabled",false);
      input_grid_nx=props.getIntProperty("binned_mode.input_grid_nx",10);
      input_grid_ny=props.getIntProperty("binned_mode.input_grid_ny",10);
      
      data_file=props.getProperty("map.data","heatmap_data.tsv");
      
      aggregated_data=props.getBooleanProperty("aggregated_data",false);
      
      String mapname = props.getProperty("map.name","santa_veiva");
      
      image_path=props.getProperty("map."+mapname+".path","santa_veiva.jpg");
      x_offset =props.getIntProperty("map."+mapname+".x_offset",8);
      y_offset = props.getIntProperty("map."+mapname+".y_offset",232);
      orig_w = props.getIntProperty("map."+mapname+".orig_w",900);
      orig_h = props.getIntProperty("map."+mapname+".orig_h",536);
      scaling_factor = props.getFloatProperty("map."+mapname+".scaling.factor",0.8);
      
      heatmap_min=props.getIntProperty("heatmap.optima.override.default.min" , 0);
      heatmap_max=props.getIntProperty("heatmap.optima.override.default.max" , 60);
      
      /*
      //Control panel settings
      float max_fps_threshold = 30;
      float min_obs_threshold = 10;
      boolean directional_mode = false;
      boolean enable_gridlines = true;
      boolean show_fps = false;
      boolean show_obs = false;
      int grid_nx=15;
      int grid_ny=10;
      int old_grid_nx,old_grid_ny;
      boolean override_optima=false;
      
      //Santa_Veiva specific settings
      float x_offset = 8;
      float y_offset = 232;
      float orig_w = 900; 
      float orig_h = 536;
      
      //Grid settings
      float grid_stroke=0.1;
      float square_opacity=180;
      */

      
   
    }catch(IOException e) {
      println("couldn't read config file...");
    }
}

void refresh_data(){
  if (binned_input == true){
    grid_nx = input_grid_nx;
    grid_ny = input_grid_ny;
  } else {
    grid_nx = max( 1, min(MAX_BINS, int( (100 - gridsize_selector.arrayValue()[0])  ) ) );
    grid_ny = max( 1, min(MAX_BINS, int( (100 - gridsize_selector.arrayValue()[1])  ) ) );
  }
  if ( grid_nx != old_grid_nx || grid_ny != old_grid_ny){
    old_grid_nx=grid_nx;
    old_grid_ny=grid_ny;
    grid_w = round( map.width / grid_nx );
    grid_h = round( map.height / grid_ny );
    reset_array();
    read_dataset();
  }
}

void setup(){

  read_config_file();
  
  println("Loading image...");
  map=loadImage(image_path);
  raw_dataset = loadStrings(data_file);

  map.resize( int(map.width*scaling_factor) , int(map.height*scaling_factor) );
  size(map.width,map.height);

  // set global variables 
  
  textSize(14);
  stroke(255,100);
  

  //cp5 control panel
  cp5 = new ControlP5(this);
  cp5.addSlider("max_fps_threshold").setPosition(width - cp5_panel_offset,25).setSize(200,20).setRange(0,60).setValue(25);
  cp5.addSlider("min_obs_threshold").setPosition(width - cp5_panel_offset,50).setSize(200,20).setRange(0,1000).setValue(200);
  cp5.addToggle("directional_mode").setPosition(width - cp5_panel_offset + 120 ,75).setSize(30,20);
  cp5.addToggle("enable_gridlines").setPosition(width -cp5_panel_offset + 120,110).setSize(30,20);
  cp5.addToggle("show_fps").setPosition(width - cp5_panel_offset + 220 ,75).setSize(30,20);
  cp5.addToggle("show_obs").setPosition(width -cp5_panel_offset + 220,110).setSize(30,20);
  cp5.addToggle("override_optima").setPosition(width - cp5_panel_offset + 220 ,150).setSize(30,20);
  if( binned_input == false )
    gridsize_selector=cp5.addSlider2D("gridsize").setPosition(width - cp5_panel_offset,75).setSize(100,100).setArrayValue(new float[] {70, 81});
  cp5.addSlider("heatmap_min").setPosition(width - cp5_panel_offset,210).setSize(200,20).setRange(0,60).setValue(25);
  cp5.addSlider("heatmap_max").setPosition(width - cp5_panel_offset,235).setSize(200,20).setRange(0,60).setValue(25);

  refresh_data();
}

void draw(){

  background(map);
  if ( binned_input == false ) refresh_data();
  if ( override_optima == false ){
    cp5.getController("heatmap_min").hide();
    cp5.getController("heatmap_max").hide();
  } else {
    cp5.getController("heatmap_min").show();
    cp5.getController("heatmap_max").show();
  }
  strokeWeight(grid_stroke);
  draw_gridlines();

  draw_heatmap();
  int bin_x = bin_pos_x(mouseX);
  int bin_y = bin_pos_y(mouseY);
  rectMode(CORNERS);
  fill(0,0);
  strokeWeight(2);
  rect(bin_x*grid_w,bin_y*grid_h,(bin_x+1)*grid_w,(bin_y+1)*grid_h);

  float current_cell_value = 0;
  int current_cell_count = 0;
  for ( int dir=0; dir<4; dir++){
    current_cell_value+=heatmap_data[dir][bin_x][bin_y][0];
    current_cell_count+=heatmap_data[dir][bin_x][bin_y][1];
  }

  String mousetext=current_cell_value+" ("+current_cell_count+")";
  fill(255);
  text(mousetext,mouseX,mouseY);

  fill(0,0,0,150);
  // rect(width-cp5_panel_offset - 20,0,width+20,250,7);

  if ( keyPressed ){
    if ( key == 's' || key == 'S' ){
      saveFrame();
    }
  }

}
