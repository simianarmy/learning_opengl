//
//  Shader.fsh
//  CubeReflectionMap
//
//  Created by Marc Mauger on 6/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

varying highp vec3 R;
uniform highp samplerCube texMap;

void main()
{
    gl_FragColor = textureCube(texMap, R);
}
