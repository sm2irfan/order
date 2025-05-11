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
