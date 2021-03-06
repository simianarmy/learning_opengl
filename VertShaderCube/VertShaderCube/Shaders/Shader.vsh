//
//  Shader.vsh
//  VertShaderCube
//
//  Created by Marc Mauger on 5/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

attribute vec4 position;
attribute vec3 normal;

varying lowp vec4 colorVarying;

uniform vec4 AmbientProduct, DiffuseProduct, SpecularProduct;
uniform mat4 ModelView;
uniform mat4 Projection;
uniform vec4 LightPosition;
uniform float Shininess;

void main()
{
    gl_Position = Projection * ModelView * position;
    
    // Transform vertex  position into eye coordinates
    vec3 pos = (ModelView * position).xyz;
    
    vec3 L = normalize( LightPosition.xyz - pos );
    vec3 E = normalize( -pos );
    vec3 H = normalize( L + E );
    
    // Transform vertex normal into eye coordinates
    vec3 N = normalize( ModelView*vec4(normal.x, normal.y, normal.z, 0.0) ).xyz;
    
    // Compute terms in the illumination equation
    vec4 ambient = AmbientProduct;
    
    float Kd = max( dot(L, N), 0.0 );
    vec4  diffuse = Kd*DiffuseProduct;
    
    float Ks = pow( max(dot(N, H), 0.0), Shininess );
    vec4  specular = Ks * SpecularProduct;
    
    if( dot(L, N) < 0.0 ) {
        specular = vec4(0.0, 0.0, 0.0, 1.0);
    } 

    colorVarying = ambient + diffuse + specular;
    colorVarying.a = 1.0;
}
