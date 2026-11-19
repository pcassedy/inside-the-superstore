-- 1. Create the database
CREATE DATABASE superstore;
USE superstore;

-- 2. Create the tables
CREATE TABLE orders (
    row_id         INT PRIMARY KEY,
    order_id       VARCHAR(20),
    order_date     DATE,
    ship_date      DATE,
    ship_mode      VARCHAR(20),
    customer_id    VARCHAR(10),
    customer_name  VARCHAR(50),
    segment        VARCHAR(20),
    country        VARCHAR(20),
    city           VARCHAR(50),
    state          VARCHAR(50),
    postal_code    VARCHAR(10),
    region         VARCHAR(10),
    product_id     VARCHAR(20),
    category       VARCHAR(20),
    sub_category   VARCHAR(20),
    product_name   VARCHAR(255),
    sales          DECIMAL(10,4),
    quantity       INT,
    discount       DECIMAL(4,2),
    profit         DECIMAL(10,4)
);

CREATE TABLE returns (
    order_id   VARCHAR(20),
    returned   VARCHAR(5)
);

CREATE TABLE people (
    regional_manager  VARCHAR(50),
    region            VARCHAR(10)
);