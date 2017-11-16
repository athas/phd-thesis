import "/futlib/colour"
import "/futlib/vec2"

module vec2 = mk_vec2 f32

type mass = f32
type position = vec2.vec
type acceleration = vec2.vec
type velocity = vec2.vec
type body = (position, mass, velocity, acceleration, argb.colour)

let mass_from_colour (c: argb.colour): f32 =
  let (r,g,b,_) = argb.to_rgba c
  in f32.max 0.3f32 (3f32 - (r + g + b))

let accel (epsilon: f32) ((pi, _, _, _ , _):body) ((pj, mj, _, _ , _): body)
        : velocity =
  let r = pj vec2.- pi
  let rsqr = vec2.dot r r + epsilon * epsilon
  let invr = 1.0f32 / f32.sqrt rsqr
  let invr3 = invr * invr * invr
  let s = mj * invr3
  in vec2.scale s r

let calc_accels [n] (epsilon: f32) (bodies: []body) (attractors: [n][]body): []acceleration =
  let move (body: body) (attractors': []body) =
        let accels = map (accel epsilon body) attractors'
        in reduce_comm (vec2.+) (0f32, 0f32) accels
  in map move bodies attractors

let advance_body (time_step: f32) ((pos, mass, vel, _, c):body) (acc:acceleration): body =
  let acc' = vec2.scale mass acc
  let pos' = pos vec2.+ vec2.scale time_step vel
  let vel' = vel vec2.+ vec2.scale time_step acc'
  in (pos', mass, vel', acc', c)

let advance_bodies [n] (epsilon: f32) (time_step: f32) (bodies: [n]body) (attractors: [n][]body): [n]body =
  let accels = calc_accels epsilon bodies attractors
  in map (advance_body time_step) bodies accels

let calc_revert_accels [n] (epsilon: f32) (bodies: []body) (orig_bodies: [n]body): []acceleration =
  let move (body: body) (orig_body: body) =
        accel epsilon orig_body body
  in map move bodies orig_bodies

let revert_bodies [n] (epsilon: f32) (time_step: f32) (bodies: [n]body) (orig_bodies: [n]body): [n]body =
  let accels = calc_revert_accels epsilon bodies orig_bodies
  in map (advance_body time_step) bodies accels

let only_nonwhites (bodies: []body) =
  let not_white ((_, _, _, _, col): body) = col != argb.white
  in filter not_white bodies

let bodies_from_pixels [h][w] (image: [h][w]i32): []body =
  let body_from_pixel (x: i32, y: i32) (pix: argb.colour) =
        ((f32.i32 x, f32.i32 y), mass_from_colour pix, (0f32, 0f32), (0f32, 0f32), pix)
  in reshape (h*w)
     (map (\(row, x) -> map (\(pix, y) -> body_from_pixel (x,y) pix) (zip row (iota w)))
            (zip image (iota h)))

let bodies_from_image [h][w] (image: [h][w]i32): []body =
  only_nonwhites (bodies_from_pixels image)

let render_body (_h: i32) (w: i32) (((x,y), _, _, _, c): body): (i32, i32) =
  if c == argb.white then (-1, c) else (i32.f32 x * w + i32.f32 y, c)

type state [h][w] = { image: [h][w]i32
                    , bodies: []body
                    , orig_bodies: []body
                    , offset: i32
                    , reverting: bool }

entry load_image [h][w] (image: [w][h][3]u8): state [h][w] =
 let pack (pix: [3]u8) = argb.from_rgba (f32.u8 pix[0] / 255f32)
                                        (f32.u8 pix[1] / 255f32)
                                        (f32.u8 pix[2] / 255f32)
                                        1f32
 in { image = transpose (map (\row -> map pack row) image)
    , bodies = empty(body)
    , orig_bodies = empty(body)
    , offset = 0
    , reverting = false }

entry render [h][w] (state: state [h][w]): [h][w]i32 =
 if length state.bodies == 0
 then state.image
 else let background = argb.white
      let (is, vs) = unzip (map (render_body h w) state.bodies)
      in reshape (h,w) (scatter (replicate (w*h) background) is vs)

entry start_nbody [h][w] (state: state [h][w]): state [h][w] =
  let bodies = bodies_from_image state.image
  in { image = state.image, bodies = bodies, orig_bodies = bodies, offset = length bodies / 2, reverting = false}

entry bodies_and_flags (state: state [][]): ([]i32, []bool) =
  let bodies = bodies_from_pixels state.image
  in ([0..<length bodies], map (\b -> b.5 != argb.white) bodies)

entry start_nbody_prefiltered [h][w] (state: state [h][w]) (is: []i32): state [h][w] =
  let all_bodies = bodies_from_pixels state.image
  let bodies = map (\i -> unsafe all_bodies[i]) is
  in { image = state.image,
       bodies = bodies,
       offset = length bodies / 2,
       orig_bodies = bodies,
       reverting = false }

let num_attractors [n] (_bodies: [n]body) = (5000*5000) / n

entry revert [h][w] ({image, bodies, offset, orig_bodies, reverting}: state [h][w]): state [h][w] =
  { image, bodies, offset, orig_bodies, reverting = true }

entry advance [h][w] ({image, bodies, offset, orig_bodies, reverting}: state [h][w]): state [h][w] =
  let n = length bodies
  let chunk_size = i32.min (num_attractors bodies) (length bodies - offset)
  let attractors = bodies[offset:offset+chunk_size]
  let bodies' = if reverting
                then revert_bodies 50f32 1f32 bodies orig_bodies
                else advance_bodies 50f32 1f32 bodies (replicate n attractors)
  in { image,
       orig_bodies,
       reverting,
       bodies = bodies',
       offset = if length bodies > 0
                then (offset + num_attractors bodies) % length bodies
                else 0 }
