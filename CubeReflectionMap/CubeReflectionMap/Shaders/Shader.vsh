//
//  Shader.vsh
//  CubeReflectionMap
//
//  Created by Marc Mauger on 6/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute highp vec4 position;
attribute highp vec4 normal;

varying highp vec3 R;

uniform highp mat4 ModelView;
uniform highp mat4 Projection;

void main()
{
    
    gl_Position = Projection * ModelView * position;
    
    highp vec4 eyePos = ModelView * position;
    highp vec4 NN = ModelView * normal;
    highp vec3 N = NN.xyz;
    // Reflect eye direction over normal
    R = reflect(eyePos.xyz, N);
}
