val generate : Random.State.t -> Types.card_def list -> Types.card_def list
(** Select up to three distinct cards; when fewer are available, return all. *)
