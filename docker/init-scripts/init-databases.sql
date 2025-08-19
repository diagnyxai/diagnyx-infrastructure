-- Database initialization script for simplified Diagnyx platform
-- This script creates the user database for the simplified architecture

-- Create user database
CREATE DATABASE user_db;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE user_db TO diagnyx;

-- Note: In the simplified architecture, we only need the user database
-- The following databases have been removed:
-- - observability_db (service removed)
-- - ai_quality_db (service removed)  
-- - optimization_db (service removed)
-- - dashboard_db (service removed)