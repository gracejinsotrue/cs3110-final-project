open Types

type json = Yojson.Safe.t
type 'a res = ('a, string list) result

(* ---------- Result helpers that keep every error ---------- *)

let err path msg = Error [ Printf.sprintf "%s: %s" path msg ]
let ( let* ) = Result.bind
let ( let+ ) r f = Result.map f r

let ( and+ ) a b =
  match (a, b) with
  | Ok x, Ok y -> Ok (x, y)
  | Error e, Ok _ | Ok _, Error e -> Error e
  | Error e1, Error e2 -> Error (e1 @ e2)

(** [all f path items] applies [f] to each item with its indexed path and
    returns every error from every item. *)
let all (f : string -> json -> 'a res) path (items : json list) : 'a list res =
  let results = List.mapi (fun i j -> f (Printf.sprintf "%s[%d]" path i) j) items in
  let errors =
    List.concat_map (function Error e -> e | Ok _ -> []) results
  in
  if errors <> [] then Error errors
  else Ok (List.filter_map Result.to_option results)

(* ---------- JSON access ---------- *)

let describe : json -> string = function
  | `Null -> "null"
  | `Bool _ -> "a boolean"
  | `Int _ | `Intlit _ -> "an integer"
  | `Float _ -> "a decimal number"
  | `String _ -> "a string"
  | `Assoc _ -> "an object"
  | `List _ -> "a list"

let as_object path : json -> (string * json) list res = function
  | `Assoc kvs -> Ok kvs
  | j -> err path ("expected an object, got " ^ describe j)

(** Reject fields that are not in [allowed] (usually typos such as "cots"),
    and fields that appear twice. *)
let check_keys path allowed kvs : unit res =
  let unknown =
    List.filter_map
      (fun (k, _) ->
        if List.mem k allowed then None
        else
          Some
            (Printf.sprintf "%s: unknown field %S (expected one of: %s)" path
               k
               (String.concat ", " allowed)))
      kvs
  in
  let rec dups seen = function
    | [] -> []
    | (k, _) :: rest ->
        if List.mem k seen then
          Printf.sprintf "%s: field %S appears more than once" path k
          :: dups seen rest
        else dups (k :: seen) rest
  in
  match unknown @ dups [] kvs with [] -> Ok () | es -> Error es

let field path kvs key : json res =
  match List.assoc_opt key kvs with
  | Some j -> Ok j
  | None -> err path (Printf.sprintf "missing field %S" key)

let get_int path kvs key : int res =
  let* j = field path kvs key in
  match j with
  | `Int n -> Ok n
  | j -> err (path ^ "." ^ key) ("expected an integer, got " ^ describe j)

let get_string path kvs key : string res =
  let* j = field path kvs key in
  match j with
  | `String s -> Ok s
  | j -> err (path ^ "." ^ key) ("expected a string, got " ^ describe j)

let get_list path kvs key : json list res =
  let* j = field path kvs key in
  match j with
  | `List l -> Ok l
  | j -> err (path ^ "." ^ key) ("expected a list, got " ^ describe j)

(** Look up a tag such as "vulnerable" in [options]. *)
let tag what options path (s : string) =
  match List.assoc_opt s options with
  | Some v -> Ok v
  | None ->
      err path
        (Printf.sprintf "unknown %s %S (expected one of: %s)" what s
           (String.concat ", " (List.map fst options)))

let get_tag what options path kvs key =
  let* s = get_string path kvs key in
  tag what options (path ^ "." ^ key) s

(** Path label for a list element that has an "id", e.g. [cards[2] ("bash")],
    so errors name the card even when its other fields are broken. *)
let with_id path kvs =
  match List.assoc_opt "id" kvs with
  | Some (`String id) -> Printf.sprintf "%s (%S)" path id
  | _ -> path

(* ---------- Tags ---------- *)

let statuses =
  [
    ("strength", Strength);
    ("weak", Weak);
    ("vulnerable", Vulnerable);
    ("poison", Poison);
  ]

let targets =
  [
    ("self", Self);
    ("selected_enemy", Selected_enemy);
    ("all_enemies", All_enemies);
  ]

let effect_types = [ "deal"; "gain_block"; "apply_status"; "draw"; "gain_energy" ]
let action_types = [ "attack"; "defend"; "inflict"; "buff" ]

let behavior_types =
  [ "cycle"; "defend_below"; "phase_at"; "random_choice" ]

(** Read the "type" field and check the object's other keys against the
    fields that type allows. *)
let typed_object what types fields_of path json =
  let* kvs = as_object path json in
  let* ty = get_string path kvs "type" in
  let* () =
    if List.mem ty types then Ok ()
    else
      err (path ^ ".type")
        (Printf.sprintf "unknown %s type %S (expected one of: %s)" what ty
           (String.concat ", " types))
  in
  let* () = check_keys path ("type" :: fields_of ty) kvs in
  Ok (ty, kvs)

(* ---------- Cards ---------- *)

let parse_effect path json : card_effect res =
  let fields_of = function
    | "deal" -> [ "target"; "amount" ]
    | "apply_status" -> [ "target"; "status"; "amount" ]
    | _ -> [ "amount" ]
  in
  let* ty, kvs = typed_object "effect" effect_types fields_of path json in
  match ty with
  | "deal" ->
      let+ t = get_tag "target" targets path kvs "target"
      and+ n = get_int path kvs "amount" in
      Deal (t, n)
  | "apply_status" ->
      let+ t = get_tag "target" targets path kvs "target"
      and+ s = get_tag "status" statuses path kvs "status"
      and+ n = get_int path kvs "amount" in
      Apply_status (t, s, n)
  | "gain_block" -> get_int path kvs "amount" |> Result.map (fun n -> Gain_block n)
  | "draw" -> get_int path kvs "amount" |> Result.map (fun n -> Draw n)
  | _ (* gain_energy *) ->
      get_int path kvs "amount" |> Result.map (fun n -> Gain_energy n)

let parse_card path json : card_def res =
  let* kvs = as_object path json in
  let path = with_id path kvs in
  let+ () =
    check_keys path [ "id"; "name"; "cost"; "description"; "effects" ] kvs
  and+ card_id = get_string path kvs "id"
  and+ card_name = get_string path kvs "name"
  and+ card_cost = get_int path kvs "cost"
  and+ card_description = get_string path kvs "description"
  and+ card_effects =
    let* effects = get_list path kvs "effects" in
    all parse_effect (path ^ ".effects") effects
  in
  { card_id; card_name; card_cost; card_description; card_effects }

(* ---------- Enemies ---------- *)

let parse_action path json : enemy_action res =
  let fields_of = function
    | "inflict" | "buff" -> [ "status"; "amount" ]
    | _ -> [ "amount" ]
  in
  let* ty, kvs = typed_object "action" action_types fields_of path json in
  match ty with
  | "attack" -> get_int path kvs "amount" |> Result.map (fun n -> Attack n)
  | "defend" -> get_int path kvs "amount" |> Result.map (fun n -> Defend n)
  | "inflict" ->
      let+ s = get_tag "status" statuses path kvs "status"
      and+ n = get_int path kvs "amount" in
      Inflict (s, n)
  | _ (* buff *) ->
      let+ s = get_tag "status" statuses path kvs "status"
      and+ n = get_int path kvs "amount" in
      Buff (s, n)

let parse_intent path json : intent res =
  let* kvs = as_object path json in
  let+ () = check_keys path [ "label"; "actions" ] kvs
  and+ intent_label = get_string path kvs "label"
  and+ intent_actions =
    let* actions = get_list path kvs "actions" in
    all parse_action (path ^ ".actions") actions
  in
  { intent_label; intent_actions }

let get_intent path kvs key =
  let* j = field path kvs key in
  parse_intent (path ^ "." ^ key) j

let get_intents path kvs key =
  let* l = get_list path kvs key in
  all parse_intent (path ^ "." ^ key) l

let parse_behavior path json : behavior res =
  let fields_of = function
    | "defend_below" -> [ "pct"; "defend"; "normal" ]
    | "phase_at" -> [ "pct"; "high"; "low" ]
    | _ -> [ "intents" ]
  in
  let* ty, kvs = typed_object "behavior" behavior_types fields_of path json in
  match ty with
  | "cycle" -> get_intents path kvs "intents" |> Result.map (fun l -> Cycle l)
  | "random_choice" ->
      get_intents path kvs "intents" |> Result.map (fun l -> Random_choice l)
  | "defend_below" ->
      let+ pct = get_int path kvs "pct"
      and+ d = get_intent path kvs "defend"
      and+ normal = get_intents path kvs "normal" in
      Defend_below (pct, d, normal)
  | _ (* phase_at *) ->
      let+ pct = get_int path kvs "pct"
      and+ high = get_intents path kvs "high"
      and+ low = get_intents path kvs "low" in
      Phase_at (pct, high, low)

let parse_enemy path json : enemy_def res =
  let* kvs = as_object path json in
  let path = with_id path kvs in
  let+ () =
    check_keys path [ "id"; "name"; "max_hp"; "gold"; "behavior" ] kvs
  and+ enemy_id = get_string path kvs "id"
  and+ enemy_name = get_string path kvs "name"
  and+ enemy_max_hp = get_int path kvs "max_hp"
  and+ enemy_gold = get_int path kvs "gold"
  and+ enemy_behavior =
    let* b = field path kvs "behavior" in
    parse_behavior (path ^ ".behavior") b
  in
  { enemy_id; enemy_name; enemy_max_hp; enemy_gold; enemy_behavior }

(* ---------- Documents and files ---------- *)

let parse_document key parse_item ~source json =
  let* kvs = as_object source json in
  let+ () = check_keys source [ key ] kvs
  and+ items =
    let* items = get_list source kvs key in
    (* Item paths look like "data/cards.json: cards[2] ("bash")". *)
    all parse_item (source ^ ": " ^ key) items
  in
  items

let parse_cards ~source json =
  let* kvs = as_object source json in
  let+ () = check_keys source [ "cards"; "reward_pool" ] kvs
  and+ cards =
    let* items = get_list source kvs "cards" in
    all parse_card (source ^ ": cards") items
  in
  cards

let parse_reward_pool ~source json =
  let* kvs = as_object source json in
  match List.assoc_opt "reward_pool" kvs with
  | None -> Ok []
  | Some (`List ids) ->
      all
        (fun path -> function
          | `String id -> Ok id
          | j -> err path ("expected a string, got " ^ describe j))
        (source ^ ": reward_pool") ids
  | Some j -> err (source ^ ".reward_pool") ("expected a list, got " ^ describe j)

let parse_enemies ~source json =
  parse_document "enemies" parse_enemy ~source json

let read_json file : json res =
  try Ok (Yojson.Safe.from_file file) with
  | Sys_error msg -> Error [ "cannot read " ^ msg ]
  | Yojson.Json_error msg ->
      let msg = String.concat " " (String.split_on_char '\n' msg) in
      Error [ Printf.sprintf "%s: invalid JSON: %s" file msg ]

let load_files ~cards ~enemies =
  let parse_file file parse =
    let* json = read_json file in
    parse ~source:file json
  in
  let parse_cards_doc () =
    let* json = read_json cards in
    let+ content_cards = parse_cards ~source:cards json
    and+ content_reward_pool = parse_reward_pool ~source:cards json in
    (content_cards, content_reward_pool)
  in
  let+ (content_cards, content_reward_pool) = parse_cards_doc ()
  and+ content_enemies = parse_file enemies parse_enemies in
  { content_cards; content_enemies; content_reward_pool }

let load dir =
  load_files
    ~cards:(Filename.concat dir "cards.json")
    ~enemies:(Filename.concat dir "enemies.json")
