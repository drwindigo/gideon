/*

  Copyright 2013 Curtis Andrus

  This file is part of Gideon.

  Gideon is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  
  Gideon is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with Gideon.  If not, see <http://www.gnu.org/licenses/>.

*/

#ifndef RT_TRANSFORM_HPP
#define RT_TRANSFORM_HPP

#include "math/vector.hpp"

namespace raytrace {

  /* Represents a mathematical transformation (rigid body, perspective) */
  struct transform {
    float4 rows[4];

    transform operator*(const transform &rhs) const;
    
    float4 apply(const float4 &v) const;
    
    float3 apply_point(const float3 &v) const;
    float3 apply_perspective(const float3 &v) const;
    float3 apply_direction(const float3 &v) const;
  };
  
};

#endif
