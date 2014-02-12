//CONFIG
//TODO move this out to a file

//Global vars
String image_path = "antarctica-map.gif";
String data_file  = "heatmap_data.tsv";
PImage map;
int grid_w, grid_h;

//Data source settings
float x_offset = 1;
float y_offset = 2;

//Grid settings
int grid_nx=20;
int grid_ny=20;
boolean draw_grid = false;
float grid_stroke=0.1;
float square_opacity=50;


float[][][][] heatmap_data =  new float[4][grid_nx][grid_ny][2];
// direction, xbin, ybin, level (val/count)

//=================================================================================


// Coordinate translation
float translate_x_coord(float x){
  return x - x_offset;
}
float translate_y_coord(float y){
  return y - y_offset;
}

int get_direction( String rot ){
  // N,E,S,W = 0,1,2,3
  float u = float ( split (rot,",")[0] );
  float v = float ( split (rot,",")[1] );
  float w = float ( split (rot,",")[2] );
  if ( w < 0.25 ) return 0;
  else if ( w < 0.5 ) return 1;
  else if ( w < 0.75 ) return 2;
  else return 3;
}

void update_heatmap_data(int binx, int biny, int dir, float fps){
  //update count and mean
  println(binx,biny,dir,fps);
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
  println("Processing dataset...");
  String[] dataset = loadStrings(data_file);
  for (int l = 0 ; l<dataset.length ; l++ )
    parse_line(dataset[l]);
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
  maxes[0]=0;  maxes[1]=0;  maxes[2]=0;  maxes[3]=0;

  for(int dir=0; dir<4; dir++)
    for(int x=0;x<grid_nx;x++)
      for(int y=0;y<grid_ny;y++)
        if (heatmap_data[dir][x][y][0] > maxes[dir]) maxes[dir]=heatmap_data[dir][x][y][0];


  for ( int x=0; x<grid_nx; x++ ){
    for ( int y=0 ; y< grid_ny; y++){
      for ( int dir = 0; dir<4; dir++){
        int tl_x = x * grid_w;
        int tl_y = y * grid_h;

        float val = heatmap_data[dir][x][y][0];
        float mx = maxes[dir];
        float opac = floor((val/mx)*square_opacity);
        // if (opac > 0 ) println(opac);
        // println(val,mx, opac);

        switch(dir){
          case 0:
            fill(#9400d3,opac);  //NORTH
            triangle(tl_x,tl_y,               tl_x+grid_w,tl_y,                tl_x+(grid_w/2),tl_y+(grid_h/2));
            break;

            case 1:
            fill(#9400d3,opac); //EAST
            triangle(tl_x+grid_w,tl_y,        tl_x+grid_w,tl_y+grid_h,         tl_x+(grid_w/2),tl_y+(grid_h/2));
            break;
         
            case 2:
            fill(#9400d3,opac); //SOUTH
            triangle(tl_x+grid_w,tl_y+grid_h, tl_x,tl_y+grid_h,                tl_x+(grid_w/2),tl_y+(grid_h/2));
            break;
          
            case 3:
            fill(#9400d3,opac); //WEST
            triangle(tl_x,tl_y,               tl_x,tl_y+grid_h,                tl_x+(grid_w/2),tl_y+(grid_h/2));
            break;
        }
        
      }
    }
  }
}

void setup(){
  map=loadImage(image_path);
  size(map.width,map.height);
  strokeWeight(grid_stroke);
  stroke(255,100);
  grid_w = round( map.width / grid_nx );
  grid_h = round( map.height / grid_ny );
  init_array();
  read_dataset();
  // print_dataset();

}

void draw(){
  background(map);
  draw_gridlines();
  draw_triangles();
  delay(1000);
}
