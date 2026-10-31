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

COMMIT TRANSACTION;

/*
  Do NOT seed real customer accounts, credentials, payment keys, or admin users here.
  Grant admin roles only after a verified user account has been created, using a
  restricted operational script or controlled admin process.
*/
