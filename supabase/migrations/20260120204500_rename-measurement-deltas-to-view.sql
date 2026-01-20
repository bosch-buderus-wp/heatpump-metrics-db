-- Rename measurement_deltas to measurement_deltas_view for consistency
-- with daily_values_view and monthly_values_view
ALTER VIEW measurement_deltas RENAME TO measurement_deltas_view;
