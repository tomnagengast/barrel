# Pathological List Parsing Test Cases

## Test 1: Deeply Nested Unordered Lists (6 levels)

- Level 1 item A
  - Level 2 item A
    - Level 3 item A
      - Level 4 item A
        - Level 5 item A
          - Level 6 item A
          - Level 6 item B
        - Level 5 item B
      - Level 4 item B
    - Level 3 item B
  - Level 2 item B
- Level 1 item B
  - Level 2 under B
    - Level 3 under B
      - Level 4 under B
        - Level 5 under B
          - Level 6 under B

## Test 2: Deeply Nested Ordered Lists (6 levels)

1. First level one
   1. Second level one
      1. Third level one
         1. Fourth level one
            1. Fifth level one
               1. Sixth level one
               2. Sixth level two
            2. Fifth level two
         2. Fourth level two
      2. Third level two
   2. Second level two
2. First level two
   1. Second level under two
      1. Third level under two
         1. Fourth level under two
            1. Fifth level under two
               1. Sixth level under two

## Test 3: Mixed Ordered and Unordered at Different Levels

1. Ordered level 1
   - Unordered level 2
     1. Ordered level 3
        - Unordered level 4
          1. Ordered level 5
             - Unordered level 6
             - Another unordered level 6
          2. Another ordered level 5
        - Another unordered level 4
     2. Another ordered level 3
   - Another unordered level 2
2. Another ordered level 1
   - Unordered child
     1. Ordered grandchild
        - Unordered great-grandchild

- Unordered level 1
  1. Ordered level 2
     - Unordered level 3
       1. Ordered level 4
          - Unordered level 5
            1. Ordered level 6
  2. Another ordered level 2
- Another unordered level 1

## Test 4: List Items with Multiple Paragraphs

- This is the first paragraph of the first list item. It contains
  enough text to make it a meaningful paragraph for testing purposes.

  This is the second paragraph of the first list item. The blank line
  above and the indentation indicate continuation of the same item.

  This is the third paragraph of the same list item. Parsers must
  correctly associate all three paragraphs with a single list item.

- This is the first paragraph of the second list item.

  This is the second paragraph of the second list item. It should be
  part of the same item, not a new block element.

- This is a single-paragraph list item for contrast.

1. Ordered item with multiple paragraphs. This first paragraph sets
   up the context for the test.

   This second paragraph is still part of ordered item one. The
   indentation must be at least 3 spaces to continue.

   This third paragraph continues the same ordered item. It tests
   whether the parser handles extended content correctly.

2. Second ordered item with two paragraphs of content that span
   more than one line each.

   This is the continuation of ordered item two. It contains some
   inline elements like **bold** and *italic* text.

3. Single paragraph ordered item.

## Test 5: Multi-Paragraph Items in Nested Lists

- Outer item one

  Continuation of outer item one.

  - Inner item one

    Continuation of inner item one.

    - Deeply inner item

      Continuation of deeply inner item. This tests three levels
      of nesting combined with multi-paragraph items.

  - Inner item two

    Continuation of inner item two.

- Outer item two

  Continuation of outer item two.

## Test 6: Lists Followed Immediately by Other Block Types

- List item one
- List item two
- List item three
# Heading Immediately After List

- Another list item
- Another list item two
> Blockquote immediately after list

1. Ordered item one
2. Ordered item two
```python
# Code fence immediately after list
def hello():
    print("world")
```

- Item before rule
- Item before rule two
---

- Item before paragraph
- Last item
This is a paragraph that comes right after the list without a blank line.

## Test 7: Single-Item Lists and Empty-ish Items

- Single item unordered list

1. Single item ordered list

-  Item with extra space before content

-

- Item after an empty-content item

1.

2. Item after an empty-content ordered item

## Test 8: Lists with Varied Markers

- Dash marker item 1
- Dash marker item 2

* Asterisk marker item 1
* Asterisk marker item 2

+ Plus marker item 1
+ Plus marker item 2

- Dash then switch
* To asterisk
+ Then plus

1. Number one
2. Number two
3. Number three

1. All ones first
1. All ones second
1. All ones third

0. Starting from zero
1. Then one
2. Then two

10. Starting from ten
11. Then eleven
12. Then twelve

## Test 9: List Item Starting with Block-Level Content

- > Blockquote inside a list item

- ```
  Code fence inside a list item
  ```

- ---

  Paragraph after a thematic break inside a list item.

- # Heading inside a list item

## Test 10: Interleaved List Types

- Unordered item

1. Ordered item

- Back to unordered

2. Ordered again starting at 2

- Unordered once more
  1. Nested ordered inside unordered
     - Nested unordered inside that
  2. Continuing nested ordered
- Final unordered
