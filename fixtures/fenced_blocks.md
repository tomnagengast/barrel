# Fenced Code Block Test Cases

This file tests fenced code blocks with various languages, fence styles, edge cases,
and interactions with inline code and surrounding content.

## 1. Standard Backtick Fence with Language Tag

```python
import asyncio
from typing import List, Optional
from dataclasses import dataclass, field

@dataclass
class Task:
    name: str
    priority: int = 0
    completed: bool = False
    subtasks: List['Task'] = field(default_factory=list)

    async def execute(self):
        print(f"Executing task: {self.name}")
        await asyncio.sleep(0.1)
        self.completed = True
        for subtask in self.subtasks:
            await subtask.execute()

async def main():
    tasks = [
        Task("Initialize", priority=1),
        Task("Process", priority=2, subtasks=[
            Task("Validate input"),
            Task("Transform data"),
            Task("Write output"),
        ]),
        Task("Cleanup", priority=3),
    ]
    for task in sorted(tasks, key=lambda t: t.priority):
        await task.execute()

if __name__ == "__main__":
    asyncio.run(main())
```

## 2. Standard Tilde Fence with Language Tag

~~~javascript
class EventEmitter {
    constructor() {
        this.listeners = new Map();
    }

    on(event, callback) {
        if (!this.listeners.has(event)) {
            this.listeners.set(event, []);
        }
        this.listeners.get(event).push(callback);
        return () => this.off(event, callback);
    }

    off(event, callback) {
        const callbacks = this.listeners.get(event);
        if (callbacks) {
            const index = callbacks.indexOf(callback);
            if (index > -1) callbacks.splice(index, 1);
        }
    }

    emit(event, ...args) {
        const callbacks = this.listeners.get(event) || [];
        callbacks.forEach(cb => cb(...args));
    }
}

const emitter = new EventEmitter();
const unsub = emitter.on('data', (payload) => {
    console.log('Received:', payload);
});

emitter.emit('data', { id: 1, value: 'hello' });
unsub(); // unsubscribe
~~~

## 3. Backtick Fence Without Language Tag

```
This is a code block with no language tag.
It should be treated as plain text or generic code.
The parser should not attempt syntax highlighting.

    Indented lines are preserved as-is.
    	Tab characters are also preserved.

Special characters: < > & " ' ` ~ * _ # @ ! $ %
```

## 4. Tilde Fence Without Language Tag

~~~
Another code block with no language specified.
Tildes should work identically to backticks
in terms of content handling.

Multiple blank lines below:


And content resumes here.
~~~

## 5. Empty Code Blocks

```python
```

~~~rust
~~~

```
```

~~~
~~~

## 6. Code Block with Blank Lines Inside

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int x;
    int y;
} Point;

Point* create_point(int x, int y) {

    Point* p = malloc(sizeof(Point));

    if (p != NULL) {
        p->x = x;
        p->y = y;
    }

    return p;

}

int main(void) {

    Point* p = create_point(10, 20);

    if (p) {
        printf("Point: (%d, %d)\n", p->x, p->y);
        free(p);
    }

    return 0;

}
```

## 7. Code Block with Multiple Consecutive Blank Lines

```
Line one.


Line four (two blank lines above).



Line eight (three blank lines above).




Line thirteen (four blank lines above).

Last line.
```

## 8. Adjacent Code Blocks (No Blank Line Between)

```python
x = 1
print(f"Python: {x}")
```
```javascript
let y = 2;
console.log(`JavaScript: ${y}`);
```
~~~ruby
z = 3
puts "Ruby: #{z}"
~~~
```go
package main
import "fmt"
func main() { fmt.Println("Go:", 4) }
```
~~~elixir
w = 5
IO.puts("Elixir: #{w}")
~~~

## 9. Code Block Containing Markdown-Like Syntax

```text
# This is NOT a heading
## Neither is this
### Nor this

- This is not a list item
* Nor is this
1. And not this either
   - Not a nested list

**Not bold** and *not italic* and ~~not strikethrough~~

[Not a link](http://example.com)
![Not an image](pic.png)

> Not a blockquote

---

This is not a horizontal rule: ***

| Not | A | Table |
|-----|---|-------|
| a   | b | c     |

- [ ] Not a task list item
- [x] Not a completed task

```not a nested fence```

Here are some backticks: ` `` ``` ```` ``````
```

## 10. Nested Fences (4 Backticks Containing 3 Backticks)

````markdown
Here is how you write a fenced code block in markdown:

```python
def greet(name):
    return f"Hello, {name}!"

print(greet("World"))
```

You can also use tildes:

```
Plain code block with no language.
```

And here is some regular markdown text between them.

```javascript
const add = (a, b) => a + b;
```

End of the markdown example.
````

## 11. Nested Fences (4 Tildes Containing 3 Tildes)

~~~~
Inside a 4-tilde fence:

~~~python
print("This inner tilde fence should be literal text.")
~~~

Still inside the outer fence.

~~~
No language on this inner fence.
~~~

And still going.
~~~~

## 12. Five Backticks Containing Four and Three

`````
Level 0 content.

````
Level 1 content (four backticks).

```
Level 2 content (three backticks).
```

Back to level 1.
````

Back to level 0.
`````

## 13. Code Fence with Info String Containing Metadata

```python title="example.py" highlight="3-5" showLineNumbers
def calculate_fibonacci(n: int) -> int:
    """Calculate the nth Fibonacci number."""
    if n <= 0:
        raise ValueError("n must be positive")
    if n <= 2:
        return 1
    a, b = 1, 1
    for _ in range(2, n):
        a, b = b, a + b
    return b
```

## 14. Tilde Fence with Info String

~~~csv separator="," encoding="utf-8"
id,name,email,role,active
1,Alice Chen,alice@example.com,admin,true
2,Bob Martinez,bob@example.com,editor,true
3,Carol Williams,carol@example.com,viewer,false
4,David Park,david@example.com,editor,true
5,Eva Johnson,eva@example.com,admin,true
~~~

## 15. Code Fence with Only Whitespace Content

```



```

## 16. Inline Code Mixed with Fenced Blocks

Here is some `inline code` in a paragraph. And here is `another piece` of inline code.

```python
# This is a fenced code block
x = "not inline code"
```

Now back to prose with `more inline code`. The variable `x` was set above.

Using double backticks for inline code with backticks inside: ``code with a ` backtick``.

```bash
echo "fenced block between inline examples"
VAR="hello"
echo $VAR
```

And triple backticks in inline code: ``` `inline triple` ``` (though this is unusual).

Here is `inline` then a fence:

~~~json
{
    "key": "value",
    "nested": {
        "array": [1, 2, 3]
    }
}
~~~

Then `inline` code again after the fence.

## 17. Various Programming Languages

```rust
use std::collections::HashMap;

fn word_count(text: &str) -> HashMap<&str, usize> {
    let mut counts = HashMap::new();
    for word in text.split_whitespace() {
        *counts.entry(word).or_insert(0) += 1;
    }
    counts
}

fn main() {
    let text = "the quick brown fox jumps over the lazy dog";
    let counts = word_count(text);
    for (word, count) in &counts {
        println!("{}: {}", word, count);
    }
}
```

```sql
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        customer_id,
        SUM(total_amount) AS monthly_total,
        COUNT(*) AS order_count
    FROM orders
    WHERE order_date >= '2025-01-01'
      AND status = 'completed'
    GROUP BY 1, 2
),
ranked AS (
    SELECT
        month,
        customer_id,
        monthly_total,
        order_count,
        ROW_NUMBER() OVER (
            PARTITION BY month
            ORDER BY monthly_total DESC
        ) AS rank
    FROM monthly_sales
)
SELECT
    month,
    customer_id,
    monthly_total,
    order_count,
    rank
FROM ranked
WHERE rank <= 10
ORDER BY month, rank;
```

```haskell
module Main where

import Data.List (sort, group, sortBy)
import Data.Ord (comparing, Down(..))

-- Count character frequencies in a string
charFrequency :: String -> [(Char, Int)]
charFrequency = sortBy (comparing (Down . snd))
              . map (\xs -> (head xs, length xs))
              . group
              . sort

-- Pretty print the frequencies
formatFrequencies :: [(Char, Int)] -> String
formatFrequencies = unlines . map (\(c, n) -> [c] ++ ": " ++ show n)

main :: IO ()
main = do
    let text = "hello world haskell"
    putStrLn $ formatFrequencies $ charFrequency text
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: production
  labels:
    app: web-server
    tier: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
        - name: nginx
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
```

```swift
import Foundation

protocol Cacheable {
    associatedtype Key: Hashable
    associatedtype Value

    func get(_ key: Key) -> Value?
    mutating func set(_ key: Key, value: Value, ttl: TimeInterval?)
    mutating func remove(_ key: Key)
}

struct LRUCache<K: Hashable, V>: Cacheable {
    typealias Key = K
    typealias Value = V

    private var storage: [K: (value: V, expiry: Date?)] = [:]
    private var accessOrder: [K] = []
    private let maxSize: Int

    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    func get(_ key: K) -> V? {
        guard let entry = storage[key] else { return nil }
        if let expiry = entry.expiry, expiry < Date() {
            return nil
        }
        return entry.value
    }

    mutating func set(_ key: K, value: V, ttl: TimeInterval? = nil) {
        let expiry = ttl.map { Date().addingTimeInterval($0) }
        storage[key] = (value: value, expiry: expiry)
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        while accessOrder.count > maxSize {
            let oldest = accessOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }

    mutating func remove(_ key: K) {
        storage.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
}
```

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard</title>
    <style>
        :root {
            --primary: #3b82f6;
            --surface: #ffffff;
            --text: #1f2937;
        }
        body {
            font-family: system-ui, -apple-system, sans-serif;
            margin: 0;
            padding: 2rem;
            color: var(--text);
            background: #f3f4f6;
        }
        .card {
            background: var(--surface);
            border-radius: 0.5rem;
            padding: 1.5rem;
            box-shadow: 0 1px 3px rgba(0,0,0,0.12);
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>Dashboard</h1>
        <p>Welcome back, <strong id="username"></strong>.</p>
    </div>
    <script>
        document.getElementById('username').textContent = 'Alice';
    </script>
</body>
</html>
```

## 18. Mismatched Fence Types (Should Not Close)

```
This opens with backticks.
~~~
The tildes above should NOT close this block.
They appear as literal text inside the block.
```

~~~
This opens with tildes.
```
The backticks above should NOT close this block.
They appear as literal text inside the block.
~~~

## 19. Closing Fence with Trailing Content

```python
print("hello")
``` this trailing text should be ignored by spec

## 20. Fence with Backticks in Info String (Edge Case)

~~~ backtick`example
This tilde fence has a backtick in its info string.
Backtick fences cannot have backticks in their info string,
but tilde fences can.
Content goes here.
~~~

## 21. Very Long Opening Fence

``````````````````````````````````````````
Content inside a fence with many backticks.
The closing fence must have at least as many.
``````````````````````````````````````````

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Content inside a fence with many tildes.
Same rule applies for tildes.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## 22. Indented Code Fences (1-3 Spaces)

 ```
 One space indented fence.
 Content is here.
 ```

  ```
  Two space indented fence.
  Content is here.
  ```

   ```
   Three space indented fence.
   Content is here.
   ```

## 23. Four-Space Indent (Should Be Indented Code Block, Not Fence)

    ```
    This should be an indented code block, not a fenced block.
    The opening fence has 4+ spaces of indentation.
    ```

## 24. Code Block Preceding Paragraph Directly

Some paragraph text right before the fence.
```
code immediately after paragraph (no blank line)
```
And text right after the closing fence (no blank line).

## 25. Adjacent Different Fence Types Alternating

```
Backtick block one
```
~~~
Tilde block one
~~~
```
Backtick block two
```
~~~
Tilde block two
~~~
```
Backtick block three
```
~~~
Tilde block three
~~~

## 26. Code Block Inside a Blockquote

> Here is a blockquote containing a code block:
>
> ```python
> def inside_blockquote():
>     return "This code is inside a blockquote"
> ```
>
> And the blockquote continues after.

> Nested blockquote with code:
> > ```javascript
> > console.log("doubly nested");
> > ```

## 27. Code Block Inside a List Item

- This list item contains a code block:

  ```go
  package main

  import "fmt"

  func main() {
      fmt.Println("Inside a list item")
  }
  ```

  And the list item continues.

1. Ordered list item with code:

   ~~~typescript
   interface Config {
       host: string;
       port: number;
       debug: boolean;
   }

   const config: Config = {
       host: "localhost",
       port: 3000,
       debug: true,
   };
   ~~~

   Text after the code block.

## 28. Code Block with Very Long Lines

```
This is a very long line that goes on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on to test horizontal scrolling behavior.
Short line.
Another very long line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

## 29. Code Block with Special Unicode Characters

```
Unicode test:
  Arrows: <- -> => <= <=> !== ===
  Math: 2 + 2 = 4, pi ≈ 3.14159, ∑(i=1..n) = n(n+1)/2
  Emoji: (not rendered in code blocks)
  CJK: 你好世界 こんにちは 안녕하세요
  Cyrillic: Привет мир
  Arabic: مرحبا بالعالم
  Box drawing: ┌──────┐
               │      │
               └──────┘
  Braille: ⠓⠑⠇⠇⠕
  Currency: $ € £ ¥ ₹ ₿
  Zero-width: [​] (zero-width space between brackets)
```

## 30. Diff Language Highlighting

```diff
--- a/config.json
+++ b/config.json
@@ -1,8 +1,10 @@
 {
   "name": "my-app",
-  "version": "1.0.0",
+  "version": "1.1.0",
   "description": "A sample application",
+  "author": "Alice Chen",
+  "license": "MIT",
   "dependencies": {
-    "express": "^4.18.0"
+    "express": "^4.19.0",
+    "cors": "^2.8.5"
   }
 }
```

## 31. Shell Session Format

```console
$ git status
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  modified:   src/app.ts
  modified:   src/utils.ts

$ git diff --stat
 src/app.ts   | 12 ++++++------
 src/utils.ts |  5 ++---
 2 files changed, 8 insertions(+), 9 deletions(-)

$ npm test
> my-app@1.0.0 test
> jest --coverage

PASS  src/__tests__/app.test.ts
PASS  src/__tests__/utils.test.ts

Test Suites: 2 passed, 2 total
Tests:       14 passed, 14 total
```

## 32. Multiple Code Blocks Telling a Story

First, define the data model:

```typescript
interface User {
    id: string;
    name: string;
    email: string;
    createdAt: Date;
}

interface CreateUserRequest {
    name: string;
    email: string;
}
```

Then, implement the repository:

```typescript
class UserRepository {
    private users: Map<string, User> = new Map();

    async create(request: CreateUserRequest): Promise<User> {
        const user: User = {
            id: crypto.randomUUID(),
            name: request.name,
            email: request.email,
            createdAt: new Date(),
        };
        this.users.set(user.id, user);
        return user;
    }

    async findById(id: string): Promise<User | undefined> {
        return this.users.get(id);
    }
}
```

Finally, write the tests:

```typescript
import { describe, it, expect, beforeEach } from 'vitest';

describe('UserRepository', () => {
    let repo: UserRepository;

    beforeEach(() => {
        repo = new UserRepository();
    });

    it('should create a user', async () => {
        const user = await repo.create({
            name: 'Alice',
            email: 'alice@example.com',
        });

        expect(user.id).toBeDefined();
        expect(user.name).toBe('Alice');
        expect(user.email).toBe('alice@example.com');
        expect(user.createdAt).toBeInstanceOf(Date);
    });

    it('should find a user by id', async () => {
        const created = await repo.create({
            name: 'Bob',
            email: 'bob@example.com',
        });

        const found = await repo.findById(created.id);
        expect(found).toEqual(created);
    });

    it('should return undefined for unknown id', async () => {
        const found = await repo.findById('nonexistent');
        expect(found).toBeUndefined();
    });
});
```

## 33. Unclosed Fence at End of File (Parser Must Auto-Close)

Some text before the unclosed fence.

```python
# This code block is intentionally left unclosed.
# Parsers should auto-close fenced code blocks at the end of the document.
# This is a valid edge case per the CommonMark specification.
def this_fence_never_closes():
    return "surprise"
