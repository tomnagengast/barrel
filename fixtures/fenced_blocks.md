# Fenced Code Block Parsing Test Cases

## Test 1: Standard Backtick Fence with Language Tag

```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

print(fibonacci(10))
```

## Test 2: Standard Tilde Fence with Language Tag

~~~javascript
function factorial(n) {
    if (n === 0) return 1;
    return n * factorial(n - 1);
}

console.log(factorial(5));
~~~

## Test 3: Backtick Fence Without Language Tag

```
This is a code block with no language tag.
It should be treated as plain text or generic code.
The parser should not attempt syntax highlighting.
```

## Test 4: Tilde Fence Without Language Tag

~~~
Another code block with no language specified.
Tildes should work identically to backticks
in terms of content handling.
~~~

## Test 5: Empty Code Block (Backticks)

```python
```

## Test 6: Empty Code Block (Tildes)

~~~rust
~~~

## Test 7: Completely Empty Code Block (No Language, No Content)

```
```

## Test 8: Empty Tilde Block (No Language, No Content)

~~~
~~~

## Test 9: Code Block with Blank Lines Inside

```c
#include <stdio.h>

int main() {

    printf("Hello, World!\n");

    return 0;

}
```

## Test 10: Code Block with Multiple Consecutive Blank Lines

```
Line one.


Line four (two blank lines above).



Line eight (three blank lines above).

Last line.
```

## Test 11: Adjacent Code Blocks (No Blank Line Between)

```python
x = 1
```
```javascript
let y = 2;
```
~~~ruby
z = 3
~~~
```go
var w int = 4
```

## Test 12: Code Block Containing Markdown-Like Syntax

```text
# This is NOT a heading
## Neither is this

- This is not a list item
* Nor is this
1. And not this either

**Not bold** and *not italic*

[Not a link](http://example.com)

> Not a blockquote

---

This is not a horizontal rule: ***

![Not an image](pic.png)

| Not | A | Table |
|-----|---|-------|
| a   | b | c     |
```

## Test 13: Nested Fences (4 Backticks Containing 3 Backticks)

````markdown
Here is an example of a code block in markdown:

```python
print("This is a nested code fence")
```

The above should be shown literally, not parsed.

```
Another nested block with no language.
```

End of outer block.
````

## Test 14: Nested Fences (4 Tildes Containing 3 Tildes)

~~~~
Inside a 4-tilde fence:

~~~
This inner tilde fence should be literal text.
~~~

Still inside the outer fence.
~~~~

## Test 15: Five Backticks Containing Four and Three

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

## Test 16: Code Fence with Info String Containing Spaces

```python title="example.py" highlight="3-5"
def greet(name):
    """Greet someone by name."""
    message = f"Hello, {name}!"
    print(message)
    return message
```

## Test 17: Tilde Fence with Info String

~~~csv separator=","
name,age,city
Alice,30,New York
Bob,25,San Francisco
Charlie,35,Chicago
~~~

## Test 18: Code Fence with Only Whitespace Content

```



```

## Test 19: Code Fence Preceded by Content on Same Consideration

Some paragraph text right before the fence.
```
code immediately after paragraph
```
And text right after the closing fence.

## Test 20: Indented Code Fence (1-3 Spaces)

 ```
 One space indented fence.
 ```

  ```
  Two space indented fence.
  ```

   ```
   Three space indented fence.
   ```

## Test 21: Mismatched Fence Types (Should Not Close)

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

## Test 22: Closing Fence with Trailing Content

```python
print("hello")
``` this trailing text should be ignored by spec

## Test 23: Fence with Backticks in Info String (Edge Case)

~~~ backtick`example
This tilde fence has a backtick in its info string.
Content goes here.
~~~

## Test 24: Very Long Opening Fence

``````````````````````````````````````````
Content inside a fence with many backticks.
The closing fence must have at least as many.
``````````````````````````````````````````

## Test 25: Code Block Containing Closing-Fence-Like Lines

```
This block contains lines that look like closing fences but aren't
because they use too few backticks or the wrong character:

`` (two backticks - not enough)
```` (four backticks - too many for a 3-backtick fence... wait, actually spec says "at least")

The above line with four backticks WOULD close a 3-backtick fence per spec.
Let's test with tildes instead inside backtick fence:

~~~ (tildes don't close a backtick fence)
~~~~~~~~ (still tildes, still doesn't close)
```

## Test 26: Adjacent Different Fence Types

```
Backtick block one
```
~~~
Tilde block right after
~~~
```
Backtick block two
```
~~~
Tilde block two
~~~

## Test 27: Code Block at End of File (No Trailing Newline)

```python
# This code block is the last thing in the file.
# Some parsers auto-close unclosed fences at EOF.
# This one IS closed, but there's no blank line after.
```