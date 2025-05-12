CREATE TABLE order_details (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(20) -- Match type with orders(id)
    product_id INT REFERENCES all_products(id) NOT NULL,
    quantity INT NOT NULL,
    unit VARCHAR(30) NOT NULL,
    discount INT,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() AT TIME ZONE 'Asia/Colombo'
);


REATE TABLE orders (
    id VARCHAR(20) PRIMARY KEY,  -- Added VARCHAR type
    user_id UUID REFERENCES auth.users(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    delivery_option VARCHAR(30) NOT NULL,
    delivery_address TEXT,       -- Keep as nullable if optional
    delivery_time_slot VARCHAR(50), -- Keep as nullable if optional
    payment_method VARCHAR(30) NOT NULL,
    order_status VARCHAR(30) DEFAULT 'Order Placed',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
    delivery_partner_name TEXT,
    delivery_partner_phone VARCHAR
);





CREATE TABLE order_details (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(20) REFERENCES orders(id) ON DELETE CASCADE, -- Match type with orders(id)
    product_id INT REFERENCES all_products(id) NOT NULL,
    quantity INT NOT NULL,
    unit VARCHAR(30) NOT NULL,
    discount INT,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() AT TIME ZONE 'Asia/Colombo'
);


REATE TABLE orders (
    id VARCHAR(20) PRIMARY KEY,  -- Added VARCHAR type
    user_id UUID REFERENCES auth.users(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    delivery_option VARCHAR(30) NOT NULL,
    delivery_address TEXT,       -- Keep as nullable if optional
    delivery_time_slot VARCHAR(50), -- Keep as nullable if optional
    payment_method VARCHAR(30) NOT NULL,
    order_status VARCHAR(30) DEFAULT 'Order Placed',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
    delivery_partner_name TEXT,
    delivery_partner_phone VARCHAR
);


CREATE TABLE all_products (
    id SERIAL PRIMARY KEY, -- Assuming 'id' is a unique identifier
    created_at TIMESTAMP NOT NULL, -- Stores the creation time
    updated_at TIMESTAMP,
    name VARCHAR(255) NOT NULL, -- Product name with a max length of 255
    uprices Text(10, 2) NOT NULL, -- Prices with up to 10 digits and 2 decimal places
    image TEXT, -- URL or path for the product image
    discount int2, -- Discount in percentage or a numeric value
    description TEXT, -- Detailed description of the product
    category_1 VARCHAR(255), -- First category (optional length adjustment)
    category_2 VARCHAR(255), -- Second category (optional length adjustment)
    popular_product bool,
    matching_words Text
);

create table public.profiles (
  id uuid references auth.users on delete cascade,
  full_name text,
  address text,
  phone_number text,
  created_at timestamptz,
  email text,
  temp_password text,
  updated_at timestamp with time zone,
  profile_number integer,
  sms_send_successfully boolean,
  primary key (id)
);

if not available create sqlite database and table for above details, when app is initialize
create appropriot file for this task 
