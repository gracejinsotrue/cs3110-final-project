open Types

let ms2_map =
  [ { node_id = 1; node_kind = Fight "training_slime"; node_row = 1; node_next = [] } ]

let generate _rng = ms2_map

let validate nodes =
  let errors = ref [] in
  let add s = errors := s :: !errors in
  let ids = List.map (fun n -> n.node_id) nodes in
  if nodes = [] then add "map is empty";
  if List.length ids <> List.length (List.sort_uniq compare ids) then
    add "map has duplicate node IDs";
  List.iter
    (fun n ->
      if n.node_id <= 0 then add (Printf.sprintf "node %d: ID must be positive" n.node_id);
      if n.node_row <= 0 then add (Printf.sprintf "node %d: row must be positive" n.node_id);
      List.iter
        (fun next_id ->
          match List.find_opt (fun x -> x.node_id = next_id) nodes with
          | None -> add (Printf.sprintf "node %d: edge to missing node %d" n.node_id next_id)
          | Some next when next.node_row <= n.node_row ->
              add (Printf.sprintf "node %d: edge must go to a later row" n.node_id)
          | Some _ -> ()) n.node_next)
    nodes;
  let starts = List.filter (fun n -> n.node_row = 1) nodes in
  if starts = [] then add "map has no starting node";
  let rec reach seen = function
    | [] -> seen
    | id :: rest when List.mem id seen -> reach seen rest
    | id :: rest ->
        let seen = id :: seen in
        let next = match List.find_opt (fun n -> n.node_id = id) nodes with
          | None -> [] | Some n -> n.node_next in
        reach seen (next @ rest)
  in
  let reached = reach [] (List.map (fun n -> n.node_id) starts) in
  List.iter (fun n -> if not (List.mem n.node_id reached) then add
    (Printf.sprintf "node %d is unreachable" n.node_id)) nodes;
  match List.rev !errors with [] -> Ok () | es -> Error es

let available nodes visited current =
  let ids = match current with
    | None -> List.filter (fun n -> n.node_row = 1) nodes |> List.map (fun n -> n.node_id)
    | Some id -> (match List.find_opt (fun n -> n.node_id = id) nodes with
        | None -> [] | Some n -> n.node_next) in
  nodes |> List.filter (fun n -> List.mem n.node_id ids && not (List.mem n.node_id visited))
