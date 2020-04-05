shader_type spatial;


uniform bool show_r;
uniform bool show_g;
uniform bool show_b;

varying vec4 col;

void vertex(){
	col = vec4(0.0,0.0,0.0,0.0);
	if(show_r){
	    col.r = COLOR.r;
	}
	if(show_g){
		col.g = COLOR.g;
	}
	if(show_b){
		col.b = COLOR.b;
	}
}

void fragment(){
	ALBEDO = col.rgb;
}