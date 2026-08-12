# WAYN — Project Instructions for Codex

## 1. PROJECT IDENTITY

Project name: WAYN
Arabic name: وين
Meaning: "Where?"

WAYN is a smart local places and services discovery application, starting with Libya.

The goal is NOT to simply create another Google Maps clone.

WAYN is intended to become a trusted digital smart directory for Libya:

* Places
* Restaurants
* Cafes
* Hotels
* Parks
* Beaches
* Markets
* Sports facilities
* Mosques
* Hospitals
* Schools
* Government services
* Businesses
* Public services
* Local activities
* Tourist destinations

The application should help users answer questions such as:

* Where can I go?
* What is near me?
* What is open now?
* What places are suitable for me?
* Where can I complete a government transaction?
* What documents are required?
* What are the working hours?
* What places are popular?
* What places are highly rated?
* What is around this location?
* What is suitable for a specific activity?

WAYN should prioritize accurate local information and excellent UX.

---

# 2. CURRENT DEVELOPMENT STACK

The current application is a Flutter application.

Main technologies:

* Flutter
* Dart
* Supabase
* PostgreSQL through Supabase
* Supabase Auth
* Supabase Storage where appropriate

The project is located at:

C:\WAYN\wayn

Do not assume that the project is empty.
There is already an existing implementation.

IMPORTANT:
Before changing architecture or rewriting major parts, inspect the existing project.

---

# 3. MOST IMPORTANT RULE

DO NOT blindly rewrite the project.

Before modifying code:

1. Inspect the relevant files.
2. Understand how the current implementation works.
3. Identify the actual cause of the problem.
4. Make the smallest safe change that solves it.
5. Preserve working functionality.
6. Run/analyze the project after modifications.
7. Fix compilation errors introduced by your changes.
8. Do not replace working code just because you prefer another architecture.

Never make large architectural changes without a strong technical reason.

---

# 4. WAYN UI/UX DIRECTION

WAYN should feel:

* Premium
* Modern
* Calm
* Fast
* Smooth
* Intelligent
* Friendly
* Local
* Professional

The interface should feel closer to a polished modern iOS application than a generic Flutter template.

Avoid:

* Cheap-looking UI
* Excessive borders
* Excessive shadows
* Huge text
* Aggressive animations
* Generic Material-looking layouts
* Ugly loading indicators
* Visual clutter
* Unnecessary dialogs
* Excessive colors

The UI must remain clean and comfortable.

---

# 5. VISUAL IDENTITY

Primary visual direction:

Turquoise / teal:
#18A99A

Dark text:
#172033

Background:
#F7F9FC

Light turquoise:
#E8F8F6

Secondary purple:
#7B61D9

Blue accents may be used when appropriate.

The visual identity should remain coherent.

Do not randomly introduce new primary colors.

---

# 6. ARABIC / RTL

Arabic is a primary language.

The application must support RTL correctly.

Arabic UI text should normally use:

TextDirection.rtl

Do not break RTL layouts when modifying widgets.

English support is also planned/required.

Do not hard-code layouts in a way that makes English impossible later.

---

# 7. HOME PAGE

The Home page is one of the most important screens.

Current conceptual structure:

1. Header
2. Search
3. Category selector
4. Filters
5. Explore by category
6. Suggestions
7. Results
8. Place cards

The Home page should prioritize useful discovery rather than simply displaying database records.

The user should quickly understand:

* what they can search
* what categories exist
* what is nearby
* what is open
* what is popular
* what WAYN recommends

---

# 8. SEARCH

Search should eventually support natural local queries.

Examples:

"مطعم قريب"
"أماكن مفتوحة الآن"
"أماكن للعائلات"
"شاطئ في طرابلس"
"مطاعم مشاوي"
"مستشفى قريب"
"وين نلقى مكان هادئ؟"

The current implementation may use ordinary database search.

Do not implement a complex AI search system unless explicitly requested.

---

# 9. CATEGORIES

Categories are important.

Current Supabase table:

categories

Known columns:

* id
* name_ar
* name_en
* icon
* sort_order
* is_active

Places contain category information and currently include:

category_id

The long-term correct relationship should be:

places.category_id -> categories.id

Do NOT rely permanently on:

places.category = categories.name_ar

unless the existing database schema requires it temporarily.

When fixing category functionality, inspect the real database responses and existing service code first.

---

# 10. IMPORTANT CURRENT ISSUE: CATEGORIES

A live read-only check showed:

categories with is_active=true -> []

categories without a filter -> []

Meanwhile:

places -> returns real data

The places contain category_id values.

Therefore the current problem is NOT necessarily the Flutter Category model.

Possible causes include:

1. categories table contains no rows
2. RLS SELECT policy prevents anon/public access
3. category records were deleted
4. category data was never seeded

When investigating this issue:

DO NOT invent category data.

Verify the database first.

If Supabase access is available, read-only inspection is allowed.

Do not perform destructive database operations unless explicitly authorized.

---

# 11. SUPABASE SAFETY

Database operations must be treated carefully.

Allowed without additional confirmation when necessary:

* SELECT
* read-only inspection
* schema inspection if supported
* checking policies

Do NOT perform without explicit user approval:

* DELETE
* DROP
* TRUNCATE
* destructive migrations
* mass UPDATE
* mass INSERT
* changing production data

If a database fix requires modifying Supabase data or policies, explain exactly what needs to change before doing it.

---

# 12. PLACE DATA

Current Place model is used by:

PlaceService
HomePage
PlaceCard
PlaceDetailsPage

Do not break these relationships.

Before changing Place fields, inspect:

lib/features/home/models/place.dart

and all usages.

---

# 13. PLACE CARDS

Place cards should look premium and modern.

Current design direction:

* Large image
* Rounded corners
* Subtle shadow
* Rating badge
* Favorite button
* Place name
* City
* Category
* Open/closed state
* Dark image gradient

The card should feel like a real commercial application.

---

# 14. IMAGE PERFORMANCE

This is an important performance problem.

Current implementation uses:

Image.network

Current images are mostly external Unsplash URLs.

The user reported that images feel slow to appear.

IMPORTANT:

Do NOT simply add an ugly CircularProgressIndicator.

The loading state should feel premium.

Preferred approach:

* skeleton/shimmer-like placeholder
* subtle animated gradient
* smooth fade-in when image arrives
* no large spinning indicator
* no visual jumping
* preserve card dimensions
* avoid blocking the rest of the page

If adding a dependency such as cached_network_image, first inspect pubspec.yaml.

Do not introduce dependencies unnecessarily.

If an existing dependency already solves the problem, use it.

---

# 15. IMAGE CACHING

The long-term goal is:

1. thumbnail for lists
2. larger image for details
3. disk caching
4. CDN/optimized image delivery
5. Supabase Storage where appropriate

However, do not migrate all existing image infrastructure blindly.

First inspect:

* image_url values
* current image providers
* existing dependencies
* Supabase Storage configuration

Then make a safe improvement.

---

# 16. LOADING UX

WAYN must avoid ugly loading states.

Do NOT use:

CircularProgressIndicator everywhere.

Prefer:

* skeleton cards
* shimmer
* subtle opacity animation
* progressive loading
* cached content
* previous content while refreshing

When data refreshes, avoid unnecessarily replacing the entire UI with an empty loading screen.

Prefer:

existing content + small visual refresh indication

where technically appropriate.

---

# 17. ERROR STATES

Different problems should have different states.

Do not show:

"لا توجد فئات متاحة"

when the actual problem is:

* network failure
* RLS
* Supabase error
* timeout
* malformed response

Distinguish:

EMPTY
ERROR
LOADING

Example:

EMPTY:
"لا توجد فئات متاحة حاليًا"

ERROR:
"تعذر تحميل الفئات"

LOADING:
skeleton UI

The user should understand what actually happened.

---

# 18. PERFORMANCE

WAYN should feel fast.

Pay attention to:

* unnecessary network requests
* duplicate requests
* large image downloads
* excessive rebuilds
* pagination
* caching
* search debounce
* race conditions
* large Supabase select queries

Current known issue:

getPlaces() loads all places without pagination.

Do not immediately redesign everything.

First determine whether pagination is currently necessary based on actual data size.

---

# 19. SEARCH REQUEST RACE CONDITIONS

Search may produce multiple asynchronous requests.

Example:

User types:

مطعم

then:

مطعم طرابلس

The older request must not overwrite the newer request.

If implementing this:

* use request IDs
* cancellation
* or another safe mechanism

Do not introduce unnecessary complexity if the current search implementation does not require it.

---

# 20. FILTERS

Current conceptual filters include:

* الأقرب
* مفتوح الآن
* الأعلى تقييمًا
* الأكثر زيارة

Be careful about semantic correctness.

If a filter is called:

"الأقرب"

it should eventually actually use location/distance.

Do not pretend that sorting by visits is "nearest".

If location functionality is not implemented yet, keep the existing behavior but clearly mark it as something to fix later rather than silently misrepresenting it.

---

# 21. ARCHITECTURE

Do not perform a massive architecture rewrite.

Current services include:

PlaceService
CategoryService

Use these existing services unless there is a concrete reason to refactor.

Long-term architecture may evolve toward:

UI
↓
Repository
↓
Service/Data source
↓
Supabase

But this should happen gradually.

---

# 22. ADMIN / DATA QUALITY

WAYN is intended to have strong local data quality.

Future systems include:

* report incorrect information
* business owner verification
* moderation
* staff roles
* analytics
* place approval
* category management
* user-generated content
* AI-assisted data enrichment

Do not implement these future systems unless explicitly requested.

However, code should not unnecessarily prevent their future implementation.

---

# 23. AI / FUTURE WAYN INTELLIGENCE

Future WAYN capabilities may include:

* personalized recommendations
* recommendation engine
* RAG
* natural language search
* image understanding
* post analysis
* comment analysis
* automatic place descriptions
* itinerary generation
* smart notifications
* "Ask WAYN"

These are future goals.

Do not pretend they are already implemented.

---

# 24. COMMUNITY

Future community features may include:

* posts
* photos
* videos
* location tagging
* comments
* likes
* favorites
* moderation

Do not implement them unless explicitly requested.

---

# 25. NAVIGATION

WAYN is not initially intended to replace Google Maps completely.

The focus is place/service information and discovery.

Maps can be used as a navigation foundation.

WAYN should eventually have its own trusted place pins/data layer.

---

# 26. CODING STYLE

Use clean Dart.

Prefer:

const

where appropriate.

Use null safety correctly.

Avoid:

dynamic

unless necessary.

Use meaningful names.

Keep methods reasonably sized.

Do not add unnecessary comments.

Existing comments may remain.

Do not introduce dead code.

Do not leave debugPrint statements in production code unless they are intentionally temporary.

---

# 27. BEFORE MODIFYING A FILE

Always inspect the file first.

If the problem crosses multiple files, inspect all relevant files.

For example, if fixing categories:

Inspect:

home_page.dart
category_service.dart
category model
place_service.dart
place model
pubspec.yaml

Do not modify only HomePage if the real problem is Supabase.

---

# 28. AFTER MODIFYING CODE

Run appropriate checks.

At minimum when possible:

flutter analyze

and if practical:

flutter test

Fix errors caused by your changes.

Do not stop at "the code looks correct".

---

# 29. DEPENDENCIES

Before adding a package:

1. Check pubspec.yaml.
2. Check whether a package already exists.
3. Check whether the current Flutter/Dart version supports it.
4. Avoid unnecessary dependencies.

Never add a package just because it is popular.

---

# 30. RELEASE SAFETY

The Android release build must have internet permission if the app requires network access.

Inspect:

android/app/src/main/AndroidManifest.xml

Do not assume debug configuration is enough.

Before release, verify:

INTERNET

is correctly declared for the release application.

---

# 31. IMPORTANT CURRENT PROJECT STATUS

Known current findings:

* Supabase places return real data.
* Supabase categories currently return an empty array.
* categories schema columns are recognized.
* Places contain category_id.
* Current place images use external URLs.
* Place cards use Image.network.
* No proper disk image caching is currently implemented.
* Home currently loads all places.
* Category selection currently uses category.nameAr when querying places.
* This should eventually use category_id.
* Category errors are currently not clearly separated from empty states.
* Search can potentially suffer from asynchronous result races.
* The "nearest" filter currently does not actually calculate distance.
* Release INTERNET permission should be verified.

These findings are based on previous project inspection and should be verified against the current code before relying on them.

---

# 32. WORKING PHILOSOPHY

The goal is not to produce the most complicated code.

The goal is:

CORRECT
+
FAST
+
BEAUTIFUL
+
MAINTAINABLE
+
SAFE

If a simple solution works better, choose the simple solution.

Do not over-engineer.

Do not rewrite working systems unnecessarily.

Do not introduce a new architecture merely for style.

---

# 33. COMMUNICATION WITH THE USER

The user is not asking for theoretical explanations when asking Codex to fix the project.

When a task is given:

1. Inspect.
2. Explain the real cause briefly.
3. Fix it.
4. Verify it.
5. Report exactly what changed.
6. Mention any remaining issue.

If something requires user action, clearly say:

USER ACTION REQUIRED

and explain the exact action.

Do not claim that something was fixed if it requires a Supabase dashboard/database change that has not actually been made.

---

# 34. NEVER DO THIS

Never:

* delete project files without permission
* rewrite the entire application unnecessarily
* replace working UI with generic templates
* invent database records
* modify production database data without approval
* hide errors as empty states
* add unnecessary dependencies
* use ugly loading spinners everywhere
* break RTL
* break existing navigation
* remove existing functionality without reason
* claim successful verification without actually verifying
* silently change the product direction

---

# 35. THE PRODUCT VISION

WAYN should eventually feel like:

"A smart local guide that actually understands Libya."

Not:

"Another map application."

Every feature should be evaluated against this vision.

The application should become:

Fast.
Accurate.
Beautiful.
Local.
Smart.
Trustworthy.
Easy to use.

When making product or technical decisions, preserve this direction.
