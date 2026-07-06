jest.mock('../../playwright/lib/pluralsight_login', () => ({
  SANDBOX_URL: 'https://sandbox.example',
  SIGNIN_URL: 'https://signin.example',
  loginWithPage: jest.fn(),
  pageLooksLoggedIn: jest.fn(),
}));

jest.mock('playwright', () => ({
  chromium: {
    connectOverCDP: jest.fn(),
  },
}));

const { chromium } = require('playwright');
const loginLib = require('../../playwright/lib/pluralsight_login');
const sessionCheck = require('../../acg_session_check');

function makePage() {
  let currentUrl = 'https://signin.example';
  return {
    goto: jest.fn(async (url) => {
      currentUrl = url;
    }),
    url: jest.fn(() => currentUrl),
    waitForTimeout: jest.fn().mockResolvedValue(undefined),
  };
}

describe('acg_session_check', () => {
  const originalEnv = process.env;
  const originalIsTTY = process.stdout.isTTY;

  let browser;
  let context;
  let page;

  beforeEach(() => {
    jest.resetAllMocks();
    process.env = { ...originalEnv };
    page = makePage();
    context = {
      newPage: jest.fn().mockResolvedValue(page),
      pages: jest.fn(() => [page]),
    };
    browser = {
      close: jest.fn().mockResolvedValue(undefined),
      contexts: jest.fn(() => [context]),
    };
    chromium.connectOverCDP.mockResolvedValue(browser);
    loginLib.pageLooksLoggedIn.mockResolvedValue(false);
    loginLib.loginWithPage.mockResolvedValue({ ok: false, reason: 'login_failed' });
    process.stdout.isTTY = true;
  });

  afterAll(() => {
    process.env = originalEnv;
    process.stdout.isTTY = originalIsTTY;
  });

  test('no creds skips auto-login attempt', async () => {
    process.env.K3DM_NONINTERACTIVE = '1';

    await expect(sessionCheck._main()).rejects.toThrow('ACG_SESSION_EXPIRED');

    expect(loginLib.loginWithPage).not.toHaveBeenCalled();
    expect(browser.close).toHaveBeenCalled();
  });

  test('noninteractive logged-out session fails fast without polling', async () => {
    process.env.K3DM_NONINTERACTIVE = '1';

    await expect(sessionCheck._main()).rejects.toThrow('ACG_SESSION_EXPIRED');

    expect(page.waitForTimeout).not.toHaveBeenCalled();
    expect(browser.close).toHaveBeenCalled();
  });
});
