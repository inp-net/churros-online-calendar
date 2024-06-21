let send_request (channel : out_channel) (request : string) : unit =
  output_string channel request;
  flush channel

let rec get_response (sock : Unix.file_descr) (channel : in_channel) : string =
  try
    let line = input_line channel in
    line ^ get_response sock channel
  with End_of_file -> Unix.close sock; ""

let http_request (request : string) (host : string) (port : int) : string =
  let ip = (Unix.gethostbyname host).h_addr_list.(0) in
  print_endline (Unix.string_of_inet_addr ip);
  let addr = Unix.ADDR_INET (ip, port) in

  let sock = Unix.(socket PF_INET SOCK_STREAM 0) in
  Unix.connect sock addr;
  
  let input = Unix.in_channel_of_descr sock in
  let output = Unix.out_channel_of_descr sock in
  
  send_request output request;
  get_response sock input

