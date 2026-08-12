from sqlalchemy import create_engine, text

engine = create_engine('postgresql://wayn_user:wayn_password@localhost:5432/wayn_db')

with engine.connect() as conn:
    # 1. Count all categories
    result = conn.execute(text('SELECT COUNT(*) AS total_categories FROM categories'))
    total_categories = result.scalar()
    print(f'1. Total categories: {total_categories}')
    
    # 2. Count active categories
    result = conn.execute(text('SELECT COUNT(*) AS active_categories FROM categories WHERE is_active = TRUE'))
    active_categories = result.scalar()
    print(f'2. Active categories: {active_categories}')
    
    # 3. Count inactive categories
    result = conn.execute(text('SELECT COUNT(*) AS inactive_categories FROM categories WHERE is_active = FALSE'))
    inactive_categories = result.scalar()
    print(f'3. Inactive categories: {inactive_categories}')
    
    # 4. Show all category records
    result = conn.execute(text('SELECT id, name_ar, name_en, is_active, sort_order, parent_id FROM categories ORDER BY sort_order, name_ar'))
    categories = result.fetchall()
    print(f'4. Category records: {len(categories)} rows')
    for row in categories:
        print(f'   - id={row[0]}, name_ar={row[1]}, name_en={row[2]}, is_active={row[3]}, sort_order={row[4]}, parent_id={row[5]}')
    
    # 5. Count places
    result = conn.execute(text('SELECT COUNT(*) AS total_places FROM places'))
    total_places = result.scalar()
    print(f'5. Total places: {total_places}')
    
    # 6. Count places having category_id
    result = conn.execute(text('SELECT COUNT(*) AS places_with_category_id FROM places WHERE category_id IS NOT NULL'))
    places_with_category_id = result.scalar()
    print(f'6. Places with category_id: {places_with_category_id}')
    
    # 7. Check orphaned category IDs
    result = conn.execute(text('''
        SELECT p.category_id, COUNT(*) AS place_count
        FROM places p
        LEFT JOIN categories c ON c.id = p.category_id
        WHERE p.category_id IS NOT NULL AND c.id IS NULL
        GROUP BY p.category_id
        ORDER BY place_count DESC
    '''))
    orphaned = result.fetchall()
    print(f'7. Orphaned category IDs: {len(orphaned)} distinct IDs')
    for row in orphaned:
        print(f'   - category_id={row[0]}, place_count={row[1]}')
    
    # 8. Check FK constraint info
    result = conn.execute(text("SELECT conname, conftype FROM pg_constraint WHERE conrelid = 'places'::regclass"))
    fk_info = result.fetchall()
    print(f'8. Foreign keys on places table: {fk_info}')