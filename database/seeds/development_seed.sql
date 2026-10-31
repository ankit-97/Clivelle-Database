/*
  Development-only seed data. Safe to re-run.
  Product photos and real inventory should be loaded from approved catalogue data.
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

MERGE dbo.Categories AS target
USING (VALUES
  (N'Claw clips', 'claw-clips', 1),
  (N'Hair clips', 'hair-clips', 2),
  (N'Hairbands', 'hairbands', 3),
  (N'Scrunchies', 'scrunchies', 4)
) AS source(name, slug, display_order)
ON target.slug = source.slug
WHEN MATCHED THEN
  UPDATE SET name = source.name, display_order = source.display_order, is_active = 1
WHEN NOT MATCHED THEN
  INSERT(name, slug, display_order, is_active)
  VALUES(source.name, source.slug, source.display_order, 1);

MERGE dbo.AdminRoles AS target
USING (VALUES ('super_admin'), ('catalog_manager'), ('order_manager'), ('support_agent')) AS source(role_name)
ON target.role_name = source.role_name
WHEN NOT MATCHED THEN INSERT(role_name) VALUES(source.role_name);

MERGE dbo.Products AS target
USING (
  SELECT c.category_id, v.sku, v.slug, v.name, v.description, v.colour, v.price, v.compare_at_price, v.is_featured
  FROM (VALUES
    ('CLV-ROSEWOOD-CLAW', 'rosewood-claw', N'Pastel Butterfly Claw Clip', N'A playful everyday claw clip with a soft pastel finish.', N'Pastel mix', CAST(299.00 AS decimal(12,2)), CAST(399.00 AS decimal(12,2)), CAST(1 AS bit), 'claw-clips'),
    ('CLV-MAUVE-CLAW', 'mauve-claw', N'Minimal Square Claw Clip', N'A clean square silhouette for an effortless hold.', N'Mauve', CAST(299.00 AS decimal(12,2)), CAST(399.00 AS decimal(12,2)), CAST(0 AS bit), 'claw-clips'),
    ('CLV-MARIGOLD-BARRETTE', 'marigold-barrette', N'Pearl Hair Clip Set', N'A polished pair of pearl clips for soft occasion styling.', N'Pearl', CAST(349.00 AS decimal(12,2)), CAST(499.00 AS decimal(12,2)), CAST(1 AS bit), 'hair-clips'),
    ('CLV-PEARL-HEADBAND', 'pearl-headband', N'Floral Hair Band', N'A comfortable floral band with a gently structured shape.', N'Navy & pink', CAST(399.00 AS decimal(12,2)), CAST(549.00 AS decimal(12,2)), CAST(0 AS bit), 'hairbands'),
    ('CLV-PETAL-CLIP', 'petal-clip', N'Crystal Hair Clip', N'A light-catching clip for a little extra sparkle.', N'Gold', CAST(349.00 AS decimal(12,2)), CAST(499.00 AS decimal(12,2)), CAST(0 AS bit), 'hair-clips'),
    ('CLV-RIBBON-SCRUNCHIE', 'ribbon-scrunchie', N'Satin Scrunchie Set (4 pcs)', N'A four-piece satin set in a soft pastel palette.', N'Pastel mix', CAST(499.00 AS decimal(12,2)), CAST(699.00 AS decimal(12,2)), CAST(1 AS bit), 'scrunchies'),
    ('CLV-CLOUD-SCRUNCHIE', 'cloud-scrunchie', N'Cloud Soft Scrunchie', N'A soft everyday scrunchie with gentle hold.', N'Ivory', CAST(129.00 AS decimal(12,2)), CAST(199.00 AS decimal(12,2)), CAST(0 AS bit), 'scrunchies'),
    ('CLV-SUNDAY-HEADBAND', 'sunday-headband', N'Sunday Comfort Headband', N'A relaxed headband made for slow mornings and easy days.', N'Blush', CAST(269.00 AS decimal(12,2)), CAST(399.00 AS decimal(12,2)), CAST(0 AS bit), 'hairbands')
  ) AS v(sku, slug, name, description, colour, price, compare_at_price, is_featured, category_slug)
  INNER JOIN dbo.Categories c ON c.slug = v.category_slug
) AS source
ON target.sku = source.sku
WHEN MATCHED THEN UPDATE SET
  category_id = source.category_id, slug = source.slug, name = source.name,
  description = source.description, colour = source.colour, price = source.price,
  compare_at_price = source.compare_at_price, is_featured = source.is_featured,
  product_status = 'active', updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(category_id, sku, slug, name, description, colour, price, compare_at_price, product_status, is_featured)
  VALUES(source.category_id, source.sku, source.slug, source.name, source.description, source.colour, source.price, source.compare_at_price, 'active', source.is_featured);

MERGE dbo.ProductImages AS target
USING (
  SELECT p.product_id, p.name, v.image_path
  FROM dbo.Products p
  INNER JOIN (VALUES
    ('rosewood-claw', 'rosewood-claw.svg'),
    ('mauve-claw', 'mauve-claw.svg'),
    ('marigold-barrette', 'marigold-barrette.svg'),
    ('pearl-headband', 'pearl-headband.svg'),
    ('petal-clip', 'petal-clip.svg'),
    ('ribbon-scrunchie', 'ribbon-scrunchie.svg'),
    ('cloud-scrunchie', 'cloud-scrunchie.svg'),
    ('sunday-headband', 'sunday-headband.svg')
  ) AS v(slug, image_path) ON v.slug = p.slug
  WHERE p.product_status = 'active'
) AS source
ON target.product_id = source.product_id AND target.is_primary = 1
WHEN MATCHED THEN UPDATE SET
  image_url = '/' + source.image_path,
  alt_text = source.name, display_order = 0
WHEN NOT MATCHED THEN INSERT(product_id, image_url, alt_text, display_order, is_primary)
  VALUES(source.product_id, '/' + source.image_path, source.name, 0, 1);

MERGE dbo.Inventory AS target
USING (SELECT product_id FROM dbo.Products WHERE product_status = 'active') AS source
ON target.product_id = source.product_id
WHEN MATCHED THEN UPDATE SET quantity_on_hand = CASE WHEN target.quantity_on_hand < 12 THEN 12 ELSE target.quantity_on_hand END,
  updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(product_id, quantity_on_hand, quantity_reserved, low_stock_threshold)
  VALUES(source.product_id, 12, 0, 3);

COMMIT TRANSACTION;

/*
  Do NOT seed real customer accounts, credentials, payment keys, or admin users here.
  Grant admin roles only after a verified user account has been created, using a
  restricted operational script or controlled admin process.
*/
