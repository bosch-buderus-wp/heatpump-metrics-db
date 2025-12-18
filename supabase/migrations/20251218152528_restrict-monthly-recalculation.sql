-- Revoke execution from everyone
REVOKE EXECUTE ON FUNCTION calculate_monthly_value_for_month(UUID, UUID, INTEGER, INTEGER, BOOLEAN) FROM PUBLIC;