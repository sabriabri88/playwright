/**
 * Copyright (c) Microsoft Corporation. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { test, expect } from '@playwright/experimental-ct-svelte';
import Counter from './Counter.svelte';

test.use({ viewport: { width: 500, height: 500 } });

test('should work', async ({ mount }) => {
  const values = [];
  const component = await mount(Counter, {
    props: {
      suffix: 'my suffix',
    },
    on: {
      changed: value => values.push(value)
    }
  });
  await expect(component).toContainText('my suffix');
  await component.click();
  expect(values).toEqual([{ count: 1 }]);
});

test('should configure app', async ({ page, mount }) => {
  const messages: string[] = [];
  page.on('console', m => messages.push(m.text()));
  await mount(Counter, {
    props: {
      units: 's',
    },
    hooksConfig: {
      route: 'A'
    }
  });
  expect(messages).toEqual(['Before mount: {\"route\":\"A\"}', 'After mount']);
});

test('should unmount', async ({ page, mount }) => {
  const component = await mount(Counter, {
    props: {
      suffix: 'my suffix',
    },
  });
  await expect(page.locator('#root')).toContainText('my suffix')
  await component.unmount();
  await expect(page.locator('#root')).not.toContainText('my suffix');
});
