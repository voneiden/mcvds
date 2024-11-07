import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import mcvds_types
import mcvds_ui

pub fn main() {
  gleeunit.main()
}

pub fn set_pinout_for_atdf_test() {
  let pinout_soic8 = mcvds_types.Pinout(mcvds_types.SOIC8, [])
  let pinout_soic14 = mcvds_types.Pinout(mcvds_types.SOIC14, [])
  let atdf_without_pinouts = mcvds_types.Atdf("", [], [], [])
  let atdf_with_soic8 = mcvds_types.Atdf("", [], [], [pinout_soic8])
  let atdf_with_soic14 = mcvds_types.Atdf("", [], [], [pinout_soic14])
  let atdf_with_both =
    mcvds_types.Atdf("", [], [], [pinout_soic8, pinout_soic14])
  [
    mcvds_ui.use_option_if_in_list_else_first(
      atdf_without_pinouts.pinouts,
      None,
    ),
    mcvds_ui.use_option_if_in_list_else_first(
      atdf_without_pinouts.pinouts,
      Some(pinout_soic14),
    ),
    mcvds_ui.use_option_if_in_list_else_first(atdf_with_soic8.pinouts, None),
    mcvds_ui.use_option_if_in_list_else_first(
      atdf_with_soic8.pinouts,
      Some(pinout_soic14),
    ),
    mcvds_ui.use_option_if_in_list_else_first(atdf_with_soic14.pinouts, None),
    mcvds_ui.use_option_if_in_list_else_first(
      atdf_with_soic14.pinouts,
      Some(pinout_soic14),
    ),
    mcvds_ui.use_option_if_in_list_else_first(atdf_with_both.pinouts, None),
    mcvds_ui.use_option_if_in_list_else_first(
      atdf_with_both.pinouts,
      Some(pinout_soic14),
    ),
  ]
  |> should.equal([
    None,
    None,
    Some(pinout_soic8),
    Some(pinout_soic8),
    Some(pinout_soic14),
    Some(pinout_soic14),
    Some(pinout_soic8),
    Some(pinout_soic14),
  ])
}
