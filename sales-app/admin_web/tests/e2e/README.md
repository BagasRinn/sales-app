# Admin Web E2E Test Suite

End-to-end tests for the `admin_web` Flutter Web application.

## Setup

```bash
# 1. Install dependencies
cd sales-app/admin_web
cd tests/e2e
npm install

# 2. Build the Flutter web app
cd ../..
flutter build web

# 3. Copy and configure environment variables
cp .env.example .env
# Edit .env with your actual test credentials

# 4. Install Playwright browsers
npx playwright install --with-deps
```

## Running Tests

```bash
# Run all tests
npm test

# Run with UI mode (visual test runner)
npm run test:ui

# Run in headed mode (see browser)
npm run test:headed

# Run smoke tests only
npm run test:smoke

# Run on specific browser
npm run test:chrome
```

## Test Structure

```
tests/e2e/
├── fixtures/          # Playwright fixtures (auth)
├── pages/            # Page Object Model
├── specs/            # Test specifications per feature
├── utils/            # Test data & helpers
├── playwright.config.ts
└── package.json
```

## Environment Variables

See `.env.example` for all available configuration options.

## Writing New Tests

1. Add a new spec file in `specs/`
2. Use the Page Object classes from `pages/`
3. Import test data from `utils/test-data.ts`
4. Mark critical tests with `@smoke` tag
