//
//  Shader.vsh
//  TetraSphereFragmentShading
//
//  Created by Marc Mauger on 5/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;
attribute vec3 normal;

// output values that will be interpolated per-fragment
varying  lowp vec3 fN;
varying  lowp vec3 fE;
varying  lowp vec3 fL;

uniform mat4 ModelView;
uniform vec4 LightPosition;
uniform mat4 Projection;

void main()
{
    fN = normal;
    fE = position.xyz;
    fL = LightPosition.xyz;
    
    if( LightPosition.w != 0.0 ) {
        fL = LightPosition.xyz - position.xyz;
    }
    gl_Position = Projection * ModelView * position;
}
