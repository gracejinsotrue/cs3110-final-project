let generate rng (pool : Types.card_def list) =
  let rec choose pool remaining picked =
    if remaining = 0 || pool = [] then List.rev picked
    else
      let i = Random.State.int rng (List.length pool) in
      let card : Types.card_def = List.nth pool i in
      let pool = List.filter (fun (c : Types.card_def) -> c.card_id <> card.card_id) pool in
      choose pool (remaining - 1) (card :: picked)
  in
  choose pool 3 []
