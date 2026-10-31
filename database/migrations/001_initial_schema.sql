/*
  Clivelle production database foundation
  Engine: Microsoft SQL Server / Azure SQL
  Apply to a NEW development database first. Review with a DBA before production.
*/
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.SchemaMigrations', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.SchemaMigrations (
    migration_id nvarchar(150) NOT NULL PRIMARY KEY,
    applied_at datetime2(3) NOT NULL CONSTRAINT DF_SchemaMigrations_applied DEFAULT SYSUTCDATETIME()
  );
END;

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Users (
    user_id uniqueidentifier NOT NULL CONSTRAINT DF_Users_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    full_name nvarchar(120) NOT NULL,
    email nvarchar(254) NULL,
    phone_e164 varchar(16) NULL,
    password_hash nvarchar(255) NULL,
    email_verified_at datetime2(3) NULL,
    phone_verified_at datetime2(3) NULL,
    account_status varchar(20) NOT NULL CONSTRAINT DF_Users_status DEFAULT 'active',
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Users_created DEFAULT SYSUTCDATETIME(),
    updated_at datetime2(3) NOT NULL CONSTRAINT DF_Users_updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_Users_status CHECK (account_status IN ('active','blocked','deleted')),
    CONSTRAINT CK_Users_contact CHECK (email IS NOT NULL OR phone_e164 IS NOT NULL)
  );
  CREATE UNIQUE INDEX UX_Users_email ON dbo.Users(email) WHERE email IS NOT NULL;
  CREATE UNIQUE INDEX UX_Users_phone ON dbo.Users(phone_e164) WHERE phone_e164 IS NOT NULL;
END;

IF OBJECT_ID(N'dbo.AuthSessions', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.AuthSessions (
    session_id uniqueidentifier NOT NULL CONSTRAINT DF_AuthSessions_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    user_id uniqueidentifier NOT NULL,
    refresh_token_hash varbinary(64) NOT NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_AuthSessions_created DEFAULT SYSUTCDATETIME(),
    expires_at datetime2(3) NOT NULL,
    revoked_at datetime2(3) NULL,
    user_agent nvarchar(500) NULL,
    ip_address varchar(45) NULL,
    CONSTRAINT FK_AuthSessions_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_AuthSessions_expiry CHECK (expires_at > created_at)
  );
  CREATE INDEX IX_AuthSessions_user ON dbo.AuthSessions(user_id, expires_at);
END;

IF OBJECT_ID(N'dbo.OtpVerifications', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.OtpVerifications (
    otp_id uniqueidentifier NOT NULL CONSTRAINT DF_Otp_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    user_id uniqueidentifier NULL,
    channel varchar(10) NOT NULL,
    destination nvarchar(254) NOT NULL,
    purpose varchar(30) NOT NULL,
    otp_hash varbinary(64) NOT NULL,
    attempts smallint NOT NULL CONSTRAINT DF_Otp_attempts DEFAULT 0,
    expires_at datetime2(3) NOT NULL,
    consumed_at datetime2(3) NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Otp_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Otp_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_Otp_channel CHECK (channel IN ('email','sms')),
    CONSTRAINT CK_Otp_attempts CHECK (attempts BETWEEN 0 AND 10)
  );
  CREATE INDEX IX_Otp_destination ON dbo.OtpVerifications(destination, purpose, expires_at);
END;

IF OBJECT_ID(N'dbo.Addresses', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Addresses (
    address_id uniqueidentifier NOT NULL CONSTRAINT DF_Addresses_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    user_id uniqueidentifier NOT NULL,
    recipient_name nvarchar(120) NOT NULL,
    phone_e164 varchar(16) NOT NULL,
    address_line1 nvarchar(200) NOT NULL,
    address_line2 nvarchar(200) NULL,
    locality nvarchar(120) NOT NULL,
    landmark nvarchar(120) NULL,
    city nvarchar(100) NOT NULL,
    state_region nvarchar(100) NOT NULL,
    postal_code varchar(12) NOT NULL,
    country_code char(2) NOT NULL CONSTRAINT DF_Addresses_country DEFAULT 'IN',
    address_type varchar(20) NOT NULL CONSTRAINT DF_Addresses_type DEFAULT 'home',
    is_default bit NOT NULL CONSTRAINT DF_Addresses_default DEFAULT 0,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Addresses_created DEFAULT SYSUTCDATETIME(),
    updated_at datetime2(3) NOT NULL CONSTRAINT DF_Addresses_updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Addresses_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_Addresses_type CHECK (address_type IN ('home','work','other'))
  );
  CREATE INDEX IX_Addresses_user ON dbo.Addresses(user_id, is_default DESC);
END;

IF OBJECT_ID(N'dbo.Categories', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Categories (
    category_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    name nvarchar(80) NOT NULL,
    slug varchar(100) NOT NULL,
    display_order int NOT NULL CONSTRAINT DF_Categories_order DEFAULT 0,
    is_active bit NOT NULL CONSTRAINT DF_Categories_active DEFAULT 1,
    CONSTRAINT UQ_Categories_name UNIQUE(name),
    CONSTRAINT UQ_Categories_slug UNIQUE(slug)
  );
END;

IF OBJECT_ID(N'dbo.Products', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Products (
    product_id uniqueidentifier NOT NULL CONSTRAINT DF_Products_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    category_id int NOT NULL,
    sku varchar(60) NOT NULL,
    slug varchar(160) NOT NULL,
    name nvarchar(160) NOT NULL,
    description nvarchar(max) NULL,
    colour nvarchar(80) NULL,
    price decimal(12,2) NOT NULL,
    compare_at_price decimal(12,2) NULL,
    product_status varchar(20) NOT NULL CONSTRAINT DF_Products_status DEFAULT 'draft',
    is_featured bit NOT NULL CONSTRAINT DF_Products_featured DEFAULT 0,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Products_created DEFAULT SYSUTCDATETIME(),
    updated_at datetime2(3) NOT NULL CONSTRAINT DF_Products_updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Products_Categories FOREIGN KEY(category_id) REFERENCES dbo.Categories(category_id),
    CONSTRAINT UQ_Products_sku UNIQUE(sku),
    CONSTRAINT UQ_Products_slug UNIQUE(slug),
    CONSTRAINT CK_Products_price CHECK (price >= 0 AND (compare_at_price IS NULL OR compare_at_price >= price)),
    CONSTRAINT CK_Products_status CHECK (product_status IN ('draft','active','archived'))
  );
  CREATE INDEX IX_Products_category_status ON dbo.Products(category_id, product_status);
END;

IF OBJECT_ID(N'dbo.ProductImages', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.ProductImages (
    image_id uniqueidentifier NOT NULL CONSTRAINT DF_ProductImages_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    product_id uniqueidentifier NOT NULL,
    image_url nvarchar(2048) NOT NULL,
    alt_text nvarchar(200) NULL,
    display_order int NOT NULL CONSTRAINT DF_ProductImages_order DEFAULT 0,
    is_primary bit NOT NULL CONSTRAINT DF_ProductImages_primary DEFAULT 0,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_ProductImages_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductImages_Products FOREIGN KEY(product_id) REFERENCES dbo.Products(product_id) ON DELETE CASCADE
  );
  CREATE INDEX IX_ProductImages_product ON dbo.ProductImages(product_id, display_order);
END;

IF OBJECT_ID(N'dbo.Inventory', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Inventory (
    product_id uniqueidentifier NOT NULL PRIMARY KEY,
    quantity_on_hand int NOT NULL CONSTRAINT DF_Inventory_on_hand DEFAULT 0,
    quantity_reserved int NOT NULL CONSTRAINT DF_Inventory_reserved DEFAULT 0,
    low_stock_threshold int NOT NULL CONSTRAINT DF_Inventory_threshold DEFAULT 3,
    updated_at datetime2(3) NOT NULL CONSTRAINT DF_Inventory_updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Inventory_Products FOREIGN KEY(product_id) REFERENCES dbo.Products(product_id),
    CONSTRAINT CK_Inventory_quantities CHECK (quantity_on_hand >= 0 AND quantity_reserved >= 0 AND quantity_reserved <= quantity_on_hand)
  );
END;

IF OBJECT_ID(N'dbo.InventoryMovements', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.InventoryMovements (
    movement_id uniqueidentifier NOT NULL CONSTRAINT DF_InventoryMovements_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    product_id uniqueidentifier NOT NULL,
    quantity_delta int NOT NULL,
    movement_type varchar(30) NOT NULL,
    reference_type varchar(30) NULL,
    reference_id uniqueidentifier NULL,
    notes nvarchar(500) NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_InventoryMovements_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_InventoryMovements_Products FOREIGN KEY(product_id) REFERENCES dbo.Products(product_id),
    CONSTRAINT CK_InventoryMovements_type CHECK (movement_type IN ('opening','restock','sale','return','adjustment','reservation','release'))
  );
  CREATE INDEX IX_InventoryMovements_product_date ON dbo.InventoryMovements(product_id, created_at DESC);
END;

IF OBJECT_ID(N'dbo.Carts', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Carts (
    cart_id uniqueidentifier NOT NULL CONSTRAINT DF_Carts_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    user_id uniqueidentifier NOT NULL,
    cart_status varchar(20) NOT NULL CONSTRAINT DF_Carts_status DEFAULT 'active',
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Carts_created DEFAULT SYSUTCDATETIME(),
    updated_at datetime2(3) NOT NULL CONSTRAINT DF_Carts_updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Carts_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_Carts_status CHECK (cart_status IN ('active','converted','abandoned'))
  );
  CREATE UNIQUE INDEX UX_Carts_one_active_per_user ON dbo.Carts(user_id) WHERE cart_status = 'active';
END;

IF OBJECT_ID(N'dbo.CartItems', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.CartItems (
    cart_item_id uniqueidentifier NOT NULL CONSTRAINT DF_CartItems_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    cart_id uniqueidentifier NOT NULL,
    product_id uniqueidentifier NOT NULL,
    quantity int NOT NULL,
    added_at datetime2(3) NOT NULL CONSTRAINT DF_CartItems_added DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_CartItems_Carts FOREIGN KEY(cart_id) REFERENCES dbo.Carts(cart_id) ON DELETE CASCADE,
    CONSTRAINT FK_CartItems_Products FOREIGN KEY(product_id) REFERENCES dbo.Products(product_id),
    CONSTRAINT UQ_CartItems_cart_product UNIQUE(cart_id, product_id),
    CONSTRAINT CK_CartItems_quantity CHECK (quantity BETWEEN 1 AND 99)
  );
END;

IF OBJECT_ID(N'dbo.Wishlists', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Wishlists (
    wishlist_id uniqueidentifier NOT NULL CONSTRAINT DF_Wishlists_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    user_id uniqueidentifier NOT NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Wishlists_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Wishlists_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT UQ_Wishlists_user UNIQUE(user_id)
  );
END;

IF OBJECT_ID(N'dbo.WishlistItems', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.WishlistItems (
    wishlist_id uniqueidentifier NOT NULL,
    product_id uniqueidentifier NOT NULL,
    added_at datetime2(3) NOT NULL CONSTRAINT DF_WishlistItems_added DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_WishlistItems PRIMARY KEY(wishlist_id, product_id),
    CONSTRAINT FK_WishlistItems_Wishlists FOREIGN KEY(wishlist_id) REFERENCES dbo.Wishlists(wishlist_id) ON DELETE CASCADE,
    CONSTRAINT FK_WishlistItems_Products FOREIGN KEY(product_id) REFERENCES dbo.Products(product_id)
  );
END;

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Orders (
    order_id uniqueidentifier NOT NULL CONSTRAINT DF_Orders_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    order_number varchar(40) NOT NULL,
    user_id uniqueidentifier NOT NULL,
    order_status varchar(24) NOT NULL CONSTRAINT DF_Orders_status DEFAULT 'pending_payment',
    currency char(3) NOT NULL CONSTRAINT DF_Orders_currency DEFAULT 'INR',
    subtotal decimal(12,2) NOT NULL,
    discount_total decimal(12,2) NOT NULL CONSTRAINT DF_Orders_discount DEFAULT 0,
    shipping_total decimal(12,2) NOT NULL CONSTRAINT DF_Orders_shipping DEFAULT 0,
    tax_total decimal(12,2) NOT NULL CONSTRAINT DF_Orders_tax DEFAULT 0,
    grand_total decimal(12,2) NOT NULL,
    shipping_address_snapshot nvarchar(max) NOT NULL,
    customer_note nvarchar(500) NULL,
    placed_at datetime2(3) NOT NULL CONSTRAINT DF_Orders_placed DEFAULT SYSUTCDATETIME(),
    updated_at datetime2(3) NOT NULL CONSTRAINT DF_Orders_updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Orders_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT UQ_Orders_number UNIQUE(order_number),
    CONSTRAINT CK_Orders_status CHECK (order_status IN ('pending_payment','paid','processing','shipped','delivered','cancelled','refunded','payment_failed')),
    CONSTRAINT CK_Orders_totals CHECK (subtotal >= 0 AND discount_total >= 0 AND shipping_total >= 0 AND tax_total >= 0 AND grand_total >= 0),
    CONSTRAINT CK_Orders_address_json CHECK (ISJSON(shipping_address_snapshot) = 1)
  );
  CREATE INDEX IX_Orders_user_placed ON dbo.Orders(user_id, placed_at DESC);
  CREATE INDEX IX_Orders_status_placed ON dbo.Orders(order_status, placed_at DESC);
END;

IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.OrderItems (
    order_item_id uniqueidentifier NOT NULL CONSTRAINT DF_OrderItems_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    order_id uniqueidentifier NOT NULL,
    product_id uniqueidentifier NULL,
    sku_snapshot varchar(60) NOT NULL,
    product_name_snapshot nvarchar(160) NOT NULL,
    image_url_snapshot nvarchar(2048) NULL,
    unit_price decimal(12,2) NOT NULL,
    quantity int NOT NULL,
    line_total decimal(12,2) NOT NULL,
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY(order_id) REFERENCES dbo.Orders(order_id) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY(product_id) REFERENCES dbo.Products(product_id),
    CONSTRAINT CK_OrderItems_values CHECK (unit_price >= 0 AND quantity > 0 AND line_total >= 0)
  );
  CREATE INDEX IX_OrderItems_order ON dbo.OrderItems(order_id);
END;

IF OBJECT_ID(N'dbo.PaymentTransactions', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.PaymentTransactions (
    payment_id uniqueidentifier NOT NULL CONSTRAINT DF_Payments_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    order_id uniqueidentifier NOT NULL,
    provider varchar(30) NOT NULL,
    provider_order_reference nvarchar(120) NULL,
    provider_payment_reference nvarchar(120) NULL,
    amount decimal(12,2) NOT NULL,
    currency char(3) NOT NULL CONSTRAINT DF_Payments_currency DEFAULT 'INR',
    payment_method varchar(30) NULL,
    payment_status varchar(20) NOT NULL CONSTRAINT DF_Payments_status DEFAULT 'created',
    idempotency_key varchar(100) NOT NULL,
    paid_at datetime2(3) NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Payments_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Payments_Orders FOREIGN KEY(order_id) REFERENCES dbo.Orders(order_id),
    CONSTRAINT UQ_Payments_idempotency UNIQUE(idempotency_key),
    CONSTRAINT CK_Payments_amount CHECK (amount >= 0),
    CONSTRAINT CK_Payments_status CHECK (payment_status IN ('created','pending','authorized','captured','failed','refunded','partially_refunded'))
  );
  CREATE INDEX IX_Payments_order ON dbo.PaymentTransactions(order_id, created_at DESC);
END;

IF OBJECT_ID(N'dbo.Coupons', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Coupons (
    coupon_id uniqueidentifier NOT NULL CONSTRAINT DF_Coupons_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    code varchar(40) NOT NULL,
    description nvarchar(200) NULL,
    discount_type varchar(12) NOT NULL,
    discount_value decimal(12,2) NOT NULL,
    minimum_order_value decimal(12,2) NOT NULL CONSTRAINT DF_Coupons_min DEFAULT 0,
    maximum_discount decimal(12,2) NULL,
    starts_at datetime2(3) NULL,
    ends_at datetime2(3) NULL,
    usage_limit int NULL,
    usage_count int NOT NULL CONSTRAINT DF_Coupons_usage DEFAULT 0,
    is_active bit NOT NULL CONSTRAINT DF_Coupons_active DEFAULT 1,
    CONSTRAINT UQ_Coupons_code UNIQUE(code),
    CONSTRAINT CK_Coupons_type CHECK (discount_type IN ('fixed','percent')),
    CONSTRAINT CK_Coupons_values CHECK (discount_value > 0 AND minimum_order_value >= 0 AND usage_count >= 0)
  );
END;

IF OBJECT_ID(N'dbo.OrderCoupons', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.OrderCoupons (
    order_id uniqueidentifier NOT NULL,
    coupon_id uniqueidentifier NOT NULL,
    discount_amount decimal(12,2) NOT NULL,
    CONSTRAINT PK_OrderCoupons PRIMARY KEY(order_id, coupon_id),
    CONSTRAINT FK_OrderCoupons_Orders FOREIGN KEY(order_id) REFERENCES dbo.Orders(order_id),
    CONSTRAINT FK_OrderCoupons_Coupons FOREIGN KEY(coupon_id) REFERENCES dbo.Coupons(coupon_id),
    CONSTRAINT CK_OrderCoupons_discount CHECK (discount_amount >= 0)
  );
END;

IF OBJECT_ID(N'dbo.Reviews', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Reviews (
    review_id uniqueidentifier NOT NULL CONSTRAINT DF_Reviews_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    user_id uniqueidentifier NOT NULL,
    product_id uniqueidentifier NOT NULL,
    order_item_id uniqueidentifier NULL,
    rating tinyint NOT NULL,
    review_title nvarchar(120) NULL,
    review_text nvarchar(1000) NULL,
    review_status varchar(16) NOT NULL CONSTRAINT DF_Reviews_status DEFAULT 'pending',
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Reviews_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Reviews_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_Reviews_Products FOREIGN KEY(product_id) REFERENCES dbo.Products(product_id),
    CONSTRAINT FK_Reviews_OrderItems FOREIGN KEY(order_item_id) REFERENCES dbo.OrderItems(order_item_id),
    CONSTRAINT CK_Reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT CK_Reviews_status CHECK (review_status IN ('pending','published','rejected'))
  );
  CREATE INDEX IX_Reviews_product_status ON dbo.Reviews(product_id, review_status, created_at DESC);
END;

IF OBJECT_ID(N'dbo.NewsletterSubscribers', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.NewsletterSubscribers (
    subscriber_id uniqueidentifier NOT NULL CONSTRAINT DF_Newsletter_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    email nvarchar(254) NOT NULL,
    subscription_status varchar(16) NOT NULL CONSTRAINT DF_Newsletter_status DEFAULT 'subscribed',
    subscribed_at datetime2(3) NOT NULL CONSTRAINT DF_Newsletter_subscribed DEFAULT SYSUTCDATETIME(),
    unsubscribed_at datetime2(3) NULL,
    CONSTRAINT UQ_Newsletter_email UNIQUE(email),
    CONSTRAINT CK_Newsletter_status CHECK (subscription_status IN ('subscribed','unsubscribed'))
  );
END;

IF OBJECT_ID(N'dbo.Shipments', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Shipments (
    shipment_id uniqueidentifier NOT NULL CONSTRAINT DF_Shipments_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    order_id uniqueidentifier NOT NULL,
    carrier nvarchar(80) NULL,
    tracking_number nvarchar(120) NULL,
    tracking_url nvarchar(2048) NULL,
    shipment_status varchar(20) NOT NULL CONSTRAINT DF_Shipments_status DEFAULT 'pending',
    shipped_at datetime2(3) NULL,
    delivered_at datetime2(3) NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_Shipments_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Shipments_Orders FOREIGN KEY(order_id) REFERENCES dbo.Orders(order_id),
    CONSTRAINT CK_Shipments_status CHECK (shipment_status IN ('pending','packed','shipped','in_transit','out_for_delivery','delivered','returned','lost'))
  );
  CREATE INDEX IX_Shipments_order ON dbo.Shipments(order_id, created_at DESC);
END;

IF OBJECT_ID(N'dbo.ShipmentEvents', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.ShipmentEvents (
    shipment_event_id uniqueidentifier NOT NULL CONSTRAINT DF_ShipmentEvents_id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    shipment_id uniqueidentifier NOT NULL,
    event_status varchar(30) NOT NULL,
    event_description nvarchar(500) NULL,
    event_location nvarchar(160) NULL,
    occurred_at datetime2(3) NOT NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_ShipmentEvents_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ShipmentEvents_Shipments FOREIGN KEY(shipment_id) REFERENCES dbo.Shipments(shipment_id) ON DELETE CASCADE
  );
  CREATE INDEX IX_ShipmentEvents_shipment_time ON dbo.ShipmentEvents(shipment_id, occurred_at);
END;

IF OBJECT_ID(N'dbo.AdminRoles', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.AdminRoles (
    role_id int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    role_name varchar(40) NOT NULL,
    CONSTRAINT UQ_AdminRoles_name UNIQUE(role_name)
  );
END;

IF OBJECT_ID(N'dbo.AdminUserRoles', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.AdminUserRoles (
    user_id uniqueidentifier NOT NULL,
    role_id int NOT NULL,
    granted_at datetime2(3) NOT NULL CONSTRAINT DF_AdminUserRoles_granted DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_AdminUserRoles PRIMARY KEY(user_id, role_id),
    CONSTRAINT FK_AdminUserRoles_Users FOREIGN KEY(user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_AdminUserRoles_Roles FOREIGN KEY(role_id) REFERENCES dbo.AdminRoles(role_id)
  );
END;

IF OBJECT_ID(N'dbo.AuditLogs', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.AuditLogs (
    audit_id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    actor_user_id uniqueidentifier NULL,
    action_name varchar(100) NOT NULL,
    entity_type varchar(80) NOT NULL,
    entity_id nvarchar(100) NULL,
    details_json nvarchar(max) NULL,
    ip_address varchar(45) NULL,
    created_at datetime2(3) NOT NULL CONSTRAINT DF_AuditLogs_created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_AuditLogs_Users FOREIGN KEY(actor_user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_AuditLogs_json CHECK (details_json IS NULL OR ISJSON(details_json) = 1)
  );
  CREATE INDEX IX_AuditLogs_entity_date ON dbo.AuditLogs(entity_type, entity_id, created_at DESC);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.SchemaMigrations WHERE migration_id = N'001_initial_schema')
  INSERT INTO dbo.SchemaMigrations(migration_id) VALUES (N'001_initial_schema');

COMMIT TRANSACTION;
