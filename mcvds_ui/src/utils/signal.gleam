import gleam/int
import gleam/option.{Some}
import gleam/regex
import gleam/result
import lustre/attribute as a

fn split_function(function: String) -> #(String, Int, Bool) {
  let assert Ok(re) = regex.from_string("([A-Z_]*)(\\d)?.*?(_ALT)?")
  let matches = regex.scan(re, function)
  case matches {
    [match, _] ->
      case match.submatches {
        [Some(name)] -> #(name, 0, False)
        [Some(name), Some(index)] -> #(
          name,
          int.parse(index) |> result.unwrap(0),
          False,
        )
        [Some(name), Some(index), Some("_ALT")] -> #(
          name,
          int.parse(index) |> result.unwrap(0),
          True,
        )
        _ -> #("", 0, False)
      }
    _ -> #("", 0, False)
  }
}

pub fn attributes(function: String) -> List(a.Attribute(a)) {
  let #(name, index, alt) = split_function(function)
  let #(text, bg) = case name {
    "VDD" -> #("text-white", "bg-red-600")
    "GND" -> #("text-white", "bg-black")
    "IOPORT" -> #("text-black", "bg-lime-400")
    "AIN" -> #("text-white", "bg-violet-800")
    "AC" -> #("text-white", "bg-violet-500")
    "DAC" -> #("text-black", "bg-violet-300")
    "EVSINCH" -> #("text-white", "bg-fuchsia-800")
    "EVAINCH" -> #("text-white", "bg-purple-800")
    "TWI" -> #("text-black", "bg-orange-500")
    "SPI" -> #("text-black", "bg-yellow-200")
    "USART" -> #("text-black", "bg-amber-400")
    "TCA" -> #("text-white", "bg-blue-700")
    "TCB" -> #("text-white", "bg-blue-500")
    "TCD" -> #("text-black", "bg-blue-300")
    "CCL" -> #("text-white", "bg-emerald-700")
    "EVSYS" -> #("text-black", "bg-emerald-400")
    "CLKCTRL" -> #("text-black", "bg-green-500")
    "PTC_X" -> #("text-white", "bg-teal-800")
    "PTC_Y" -> #("text-white", "bg-teal-600")
    "PTC_DS" -> #("text-black", "bg-teal-400")
    "BREAK" -> #("text-white", "bg-indigo-800")
    "OTHER" -> #("text-white", "bg-indigo-500")
    _ -> #("text-white", "bg-stone-800")
  }
  let base_colors = [a.class(text), a.class(bg)]
  case alt {
    True -> [
      a.style([
        #(
          "background-image",
          "repeating-linear-gradient(45deg, rgba(0,0,0,0), rgba(0,0,0,0) 10px, rgba(0,0,0,0.25) 0, rgba(0,0,0,0.25) 20px)",
        ),
      ]),
      ..base_colors
    ]
    False -> base_colors
  }
}
