# Purpose

We want to have a clear and consistent way of naming and structuring our database.
This document is written in a way to be consumed by both humans and LLMs.

# Naming Conventions

## Tables & Views

- Use _lowercase snake_case_
- Use _plural_ because tables contain many elements
- Use descriptive names

## Columns

- Use _lowercase snake_case_
- Use _singular_ because columns refer to a single-valued property of an element
- Use _unit postfix_ if the column refers to a measurement with a unit, e.g. `thermal_energy_kwh` to make it clear which unit is used
  - Use `c` for Celsius or K for temperature
  - Use `kwh` for energy
  - Use `m2` for area
- Use _id_ for unique identifiers and _prefix_ the id for foreign keys, e.g. `user_id` for the id of the user
- Use descriptive names
- Use _nullable_ if the column can be empty
- Use _not nullable_ if the column cannot be empty
- Use _default_ if the column has a default value
