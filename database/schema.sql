CREATE DATABASE IF NOT EXISTS campus_resources
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE campus_resources;

CREATE TABLE IF NOT EXISTS departments (
  department_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  code VARCHAR(16) NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
  user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_id BIGINT UNSIGNED NULL,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('ADMIN', 'STAFF', 'STUDENT') NOT NULL DEFAULT 'STAFF',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_department FOREIGN KEY (department_id)
    REFERENCES departments (department_id) ON DELETE SET NULL
);

ALTER TABLE users
  MODIFY COLUMN role ENUM('ADMIN', 'STAFF', 'STUDENT') NOT NULL DEFAULT 'STAFF';

CREATE TABLE IF NOT EXISTS categories (
  category_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80) NOT NULL UNIQUE,
  description VARCHAR(255) NULL
);

CREATE TABLE IF NOT EXISTS locations (
  location_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_id BIGINT UNSIGNED NULL,
  name VARCHAR(120) NOT NULL UNIQUE,
  location_type ENUM('STORE', 'LAB', 'OFFICE', 'OTHER') NOT NULL DEFAULT 'LAB',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_locations_department FOREIGN KEY (department_id)
    REFERENCES departments (department_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS resources (
  resource_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_id BIGINT UNSIGNED NOT NULL,
  sku VARCHAR(40) NOT NULL UNIQUE,
  name VARCHAR(140) NOT NULL,
  unit VARCHAR(32) NOT NULL DEFAULT 'unit',
  resource_type ENUM('REUSABLE', 'CONSUMABLE') NOT NULL DEFAULT 'REUSABLE',
  description VARCHAR(500) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_resources_category FOREIGN KEY (category_id)
    REFERENCES categories (category_id) ON DELETE RESTRICT,
  INDEX idx_resources_name (name)
);

CREATE TABLE IF NOT EXISTS inventory (
  inventory_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  resource_id BIGINT UNSIGNED NOT NULL,
  location_id BIGINT UNSIGNED NOT NULL,
  on_hand INT UNSIGNED NOT NULL DEFAULT 0,
  checked_out INT UNSIGNED NOT NULL DEFAULT 0,
  minimum_required INT UNSIGNED NOT NULL DEFAULT 0,
  reorder_level INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_inventory_resource_location UNIQUE (resource_id, location_id),
  CONSTRAINT chk_inventory_checked_out CHECK (checked_out <= on_hand),
  CONSTRAINT chk_inventory_reorder CHECK (reorder_level >= 0),
  CONSTRAINT fk_inventory_resource FOREIGN KEY (resource_id)
    REFERENCES resources (resource_id) ON DELETE RESTRICT,
  CONSTRAINT fk_inventory_location FOREIGN KEY (location_id)
    REFERENCES locations (location_id) ON DELETE RESTRICT,
  INDEX idx_inventory_location (location_id),
  INDEX idx_inventory_resource (resource_id)
);

CREATE TABLE IF NOT EXISTS resource_requests (
  request_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_id BIGINT UNSIGNED NOT NULL,
  resource_id BIGINT UNSIGNED NOT NULL,
  requested_by BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  fulfilled_quantity INT UNSIGNED NOT NULL DEFAULT 0,
  priority ENUM('LOW', 'MEDIUM', 'HIGH', 'URGENT') NOT NULL DEFAULT 'MEDIUM',
  status ENUM('PENDING', 'PARTIALLY_FULFILLED', 'FULFILLED', 'CANCELLED')
    NOT NULL DEFAULT 'PENDING',
  needed_by DATE NULL,
  purpose VARCHAR(500) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_request_quantity CHECK (quantity > 0),
  CONSTRAINT chk_request_fulfilled CHECK (fulfilled_quantity <= quantity),
  CONSTRAINT fk_requests_department FOREIGN KEY (department_id)
    REFERENCES departments (department_id) ON DELETE RESTRICT,
  CONSTRAINT fk_requests_resource FOREIGN KEY (resource_id)
    REFERENCES resources (resource_id) ON DELETE RESTRICT,
  CONSTRAINT fk_requests_user FOREIGN KEY (requested_by)
    REFERENCES users (user_id) ON DELETE RESTRICT,
  INDEX idx_requests_status_priority (status, priority, created_at),
  INDEX idx_requests_department (department_id)
);

CREATE TABLE IF NOT EXISTS transfers (
  transfer_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  request_id BIGINT UNSIGNED NOT NULL,
  resource_id BIGINT UNSIGNED NOT NULL,
  source_location_id BIGINT UNSIGNED NOT NULL,
  destination_location_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  approved_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_transfer_quantity CHECK (quantity > 0),
  CONSTRAINT chk_transfer_locations CHECK (source_location_id <> destination_location_id),
  CONSTRAINT fk_transfers_request FOREIGN KEY (request_id)
    REFERENCES resource_requests (request_id) ON DELETE RESTRICT,
  CONSTRAINT fk_transfers_resource FOREIGN KEY (resource_id)
    REFERENCES resources (resource_id) ON DELETE RESTRICT,
  CONSTRAINT fk_transfers_source FOREIGN KEY (source_location_id)
    REFERENCES locations (location_id) ON DELETE RESTRICT,
  CONSTRAINT fk_transfers_destination FOREIGN KEY (destination_location_id)
    REFERENCES locations (location_id) ON DELETE RESTRICT,
  CONSTRAINT fk_transfers_user FOREIGN KEY (approved_by)
    REFERENCES users (user_id) ON DELETE RESTRICT,
  INDEX idx_transfers_request (request_id, created_at)
);

CREATE TABLE IF NOT EXISTS stock_transactions (
  transaction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  resource_id BIGINT UNSIGNED NOT NULL,
  location_id BIGINT UNSIGNED NOT NULL,
  actor_id BIGINT UNSIGNED NULL,
  transaction_type ENUM('RECEIPT', 'TRANSFER_IN', 'TRANSFER_OUT', 'ADJUSTMENT', 'CHECKOUT', 'RETURN', 'CONSUME')
    NOT NULL,
  quantity_delta INT NOT NULL,
  reference_type VARCHAR(32) NULL,
  reference_id BIGINT UNSIGNED NULL,
  notes VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_stock_delta CHECK (quantity_delta <> 0),
  CONSTRAINT fk_stock_resource FOREIGN KEY (resource_id)
    REFERENCES resources (resource_id) ON DELETE RESTRICT,
  CONSTRAINT fk_stock_location FOREIGN KEY (location_id)
    REFERENCES locations (location_id) ON DELETE RESTRICT,
  CONSTRAINT fk_stock_actor FOREIGN KEY (actor_id)
    REFERENCES users (user_id) ON DELETE SET NULL,
  INDEX idx_stock_history (resource_id, location_id, created_at)
);

CREATE TABLE IF NOT EXISTS resource_usage (
  usage_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  resource_id BIGINT UNSIGNED NOT NULL,
  location_id BIGINT UNSIGNED NOT NULL,
  actor_id BIGINT UNSIGNED NOT NULL,
  action ENUM('CHECKOUT', 'RETURN', 'CONSUME') NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_resource_usage_quantity CHECK (quantity > 0),
  CONSTRAINT fk_usage_resource FOREIGN KEY (resource_id)
    REFERENCES resources (resource_id) ON DELETE RESTRICT,
  CONSTRAINT fk_usage_location FOREIGN KEY (location_id)
    REFERENCES locations (location_id) ON DELETE RESTRICT,
  CONSTRAINT fk_usage_actor FOREIGN KEY (actor_id)
    REFERENCES users (user_id) ON DELETE RESTRICT,
  INDEX idx_usage_resource_location_created (resource_id, location_id, created_at)
);

CREATE TABLE IF NOT EXISTS low_stock_alerts (
  alert_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  inventory_id BIGINT UNSIGNED NOT NULL,
  observed_quantity INT UNSIGNED NOT NULL,
  reorder_level INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP NULL,
  CONSTRAINT fk_alert_inventory FOREIGN KEY (inventory_id)
    REFERENCES inventory (inventory_id) ON DELETE CASCADE,
  INDEX idx_alerts_open (resolved_at, created_at)
);
