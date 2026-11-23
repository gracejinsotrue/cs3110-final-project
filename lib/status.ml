open Types

(** [count s m] is how many stacks/turns of [s] are in [m] (0 if absent). *)
let count s m = Option.value (List.assoc_opt s m) ~default:0

let apply s n m =
  if n <= 0 then m
  else if List.mem_assoc s m then
    List.map (fun (s', k) -> if s' = s then (s', k + n) else (s', k)) m
  else (s, n) :: m

(** Statuses that lose 1 at the end of each action. Strength never ticks. *)
let ticks_down = function
  | Poison | Weak | Vulnerable -> true
  | Strength -> false

let tick m =
  let poison = count Poison m in
  let m' =
    m
    |> List.map (fun (s, k) -> if ticks_down s then (s, k - 1) else (s, k))
    |> List.filter (fun (_, k) -> k > 0)
  in
  (m', poison)

let outgoing m dmg =
  let x = dmg + count Strength m in
  let x = if count Weak m > 0 then x * 3 / 4 else x in
  max 0 x

let incoming m dmg =
  let x = max 0 dmg in
  if count Vulnerable m > 0 then x * 3 / 2 else x
