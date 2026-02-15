# Pathological List Test Cases

This file tests deeply nested lists, mixed list types, and edge cases for markdown parsers.

## 1. Deeply Nested Unordered Lists (6 levels)

- Level 1: Application Architecture
  - Level 2: Frontend Layer
    - Level 3: Component Library
      - Level 4: Atomic Components
        - Level 5: Button variants
          - Level 6: Primary button with icon
          - Level 6: Secondary button disabled state
          - Level 6: Ghost button with tooltip
        - Level 5: Input field variants
          - Level 6: Text input with validation
          - Level 6: Number input with stepper
          - Level 6: Date picker with range selection
      - Level 4: Composite Components
        - Level 5: Navigation bar
          - Level 6: Mobile hamburger menu
          - Level 6: Desktop dropdown menus
          - Level 6: Breadcrumb trail with overflow
        - Level 5: Data tables
          - Level 6: Sortable columns
          - Level 6: Filterable rows
          - Level 6: Paginated results
          - Level 6: Expandable row details
    - Level 3: State Management
      - Level 4: Global State
        - Level 5: User authentication
          - Level 6: Token refresh logic
          - Level 6: Session timeout handling
        - Level 5: Application settings
          - Level 6: Theme preferences
          - Level 6: Language/locale settings
      - Level 4: Local State
        - Level 5: Form state
          - Level 6: Dirty field tracking
          - Level 6: Validation error messages
        - Level 5: UI state
          - Level 6: Modal open/close
          - Level 6: Sidebar collapsed/expanded
  - Level 2: Backend Layer
    - Level 3: API Gateway
      - Level 4: Route handling
        - Level 5: Authentication middleware
          - Level 6: JWT validation
          - Level 6: API key verification
        - Level 5: Rate limiting
          - Level 6: Per-user limits
          - Level 6: Per-endpoint limits
    - Level 3: Service Layer
      - Level 4: Business Logic
        - Level 5: Order processing
          - Level 6: Inventory check
          - Level 6: Payment capture
          - Level 6: Shipping calculation
        - Level 5: User management
          - Level 6: Registration flow
          - Level 6: Password reset
          - Level 6: Profile updates

## 2. Deeply Nested Ordered Lists (6 levels)

1. Project Planning Phase
   1. Requirements Gathering
      1. Stakeholder Interviews
         1. Executive team meetings
            1. CEO vision alignment
               1. Quarterly objectives review
               2. Budget allocation discussion
               3. Resource commitment confirmation
            2. CTO technical direction
               1. Technology stack preferences
               2. Infrastructure constraints
               3. Security requirements
         2. Department head sessions
            1. Marketing department needs
               1. Campaign tracking features
               2. Analytics dashboard requirements
               3. A/B testing capabilities
            2. Sales department needs
               1. CRM integration requirements
               2. Pipeline visualization needs
               3. Reporting and forecasting tools
      2. User Research
         1. Survey Design
            1. Question formulation
               1. Open-ended questions
               2. Likert scale questions
               3. Multiple choice questions
            2. Distribution strategy
               1. Email campaigns
               2. In-app prompts
               3. Social media outreach
         2. Interview Sessions
            1. Participant recruitment
               1. Screening criteria definition
               2. Scheduling logistics
               3. Compensation planning
            2. Interview execution
               1. Recording setup
               2. Note-taking protocol
               3. Follow-up question framework
   2. Technical Specification
      1. Architecture Design
         1. System Components
            1. Frontend architecture
               1. SPA vs SSR decision
               2. Component library selection
               3. Build toolchain configuration
            2. Backend architecture
               1. Monolith vs microservices
               2. Database selection
               3. Cache layer design
      2. API Design
         1. REST endpoints
            1. Resource naming conventions
               1. Plural vs singular nouns
               2. Nested resource paths
               3. Query parameter standards
            2. HTTP method mapping
               1. GET for retrieval
               2. POST for creation
               3. PUT/PATCH for updates
               4. DELETE for removal
         2. GraphQL schema
            1. Type definitions
               1. Query root type
               2. Mutation root type
               3. Subscription root type

## 3. Mixed Ordered and Unordered Lists

1. First ordered item
   - Unordered sub-item alpha
   - Unordered sub-item beta
     1. Back to ordered, deeply nested
     2. Another ordered item
        - And unordered again
          1. Ordered once more
             - Final unordered level
             - Another item here
          2. Parallel ordered item
        - Parallel unordered item
     3. Third ordered item
   - Unordered sub-item gamma
2. Second ordered item
   1. Ordered sub-item
      - Unordered sub-sub-item
        1. Mixed deep nesting level 4
           - Mixed deep nesting level 5
             1. Mixed deep nesting level 6 (ordered)
             2. Still at level 6
           - Back to level 5 unordered
        2. Back to level 4 ordered
      - Another unordered sub-sub-item
   2. Another ordered sub-item
3. Third ordered item
   - Quick unordered note
   - Another note
     - Deeper note
       - Even deeper

- Unordered level 1
  1. Ordered level 2
     - Unordered level 3
       1. Ordered level 4
          - Unordered level 5
            1. Ordered level 6
  2. Another ordered level 2
- Another unordered level 1

## 4. List Items with Multiple Paragraphs

- This is the first list item. It has a short first paragraph.

  This is a continuation paragraph within the same list item. It should be
  indented to align with the text of the list item above. Some markdown
  parsers are strict about this indentation, requiring exactly 2 or 4 spaces.

  And here is yet another paragraph in the same list item. This tests whether
  the parser correctly maintains the list context across multiple blank lines
  and paragraph breaks.

- This is the second list item with multiple paragraphs.

  The second paragraph of the second item. This contains some **bold text**
  and some *italic text* to test inline formatting within continuation
  paragraphs inside list items.

  > This is a blockquote inside a list item. Some parsers struggle with this
  > combination, especially when the blockquote spans multiple lines and
  > contains its own formatting.

  Back to a regular paragraph after the blockquote.

- Third list item.

  This item contains a code block:

  ```python
  def hello():
      print("Hello from inside a list item!")
      return True
  ```

  And text continues after the code block, still within the same list item.

- Fourth list item with a table inside:

  | Column A | Column B | Column C |
  |----------|----------|----------|
  | Value 1  | Value 2  | Value 3  |
  | Value 4  | Value 5  | Value 6  |

  And a paragraph after the table.

1. Ordered item with multiple paragraphs.

   This is the continuation paragraph for the ordered list item. Note that
   for ordered lists, the indentation typically needs to be 3 or 4 spaces
   to align with the text after the number and period.

   Another paragraph here. Testing that the ordered list context is maintained
   properly across paragraph boundaries.

2. Second ordered item.

   With its own continuation paragraph that contains a [link to example](https://example.com)
   and an ![image alt text](https://example.com/image.png) reference.

3. Third ordered item.

   This one has a nested list inside:

   - Nested unordered item A
   - Nested unordered item B

   And then continues with another paragraph after the nested list.

## 5. Multi-Paragraph Items in Nested Lists

- Outer item one

  Continuation of outer item one. This is a long paragraph that
  provides context for the nested items below.

  - Inner item one

    Continuation of inner item one. This tests nesting with
    multi-paragraph content.

    - Deeply inner item

      Continuation of deeply inner item. This tests three levels
      of nesting combined with multi-paragraph items. The parser
      must track indentation carefully here.

      And another paragraph at the deepest level.

  - Inner item two

    Continuation of inner item two. Each of these nested items
    has its own continuation paragraph.

- Outer item two

  Continuation of outer item two.

  1. Nested ordered item with paragraph.

     This paragraph belongs to the nested ordered item, which
     itself is inside an unordered list item.

     1. Even deeper ordered item.

        With its own continuation paragraph spanning
        multiple lines.

## 6. Lists Followed by Other Block Elements

- List item one
- List item two
- List item three

# Heading Immediately After List

- Another list item
- Another list item two

> Blockquote after a blank line following a list

1. Ordered item one
2. Ordered item two

```python
# Code fence after a list
def hello():
    print("world")
```

- Item before rule
- Item before rule two

---

- Item after horizontal rule (new list)

- Item before paragraph
- Last item

This is a paragraph that comes right after the list with a blank line.

## 7. Single-Item Lists and Empty-ish Items

- Single item unordered list

1. Single item ordered list

-  Item with extra space before content

-

- Item after an empty-content dash item

1.

2. Item after an empty-content ordered item

-      Item with many spaces before content

## 8. Lists with Varied Markers

Test that parsers handle all valid unordered list markers:

- Dash item 1
- Dash item 2
- Dash item 3

* Asterisk item 1
* Asterisk item 2
* Asterisk item 3

+ Plus item 1
+ Plus item 2
+ Plus item 3

Mixed markers at the same level (each starts a new list per spec):

- Dash item
* Asterisk item
+ Plus item

## 9. Ordered Lists with Various Number Formats

1. First item
2. Second item
3. Third item

Starting from a different number:

3. This starts at three
4. Then four
5. Then five

All ones (lazy numbering):

1. First item
1. Second item
1. Third item
1. Fourth item

Large numbers:

100. Item one hundred
101. Item one hundred one
102. Item one hundred two

Zero start:

0. Zero-indexed item
1. First item
2. Second item

Very large start number:

999999999. Near the boundary
1000000000. At the boundary (may not be valid per spec)

## 10. Lists with Inline Formatting

- **Bold list item** with trailing text
- *Italic list item* with trailing text
- ***Bold and italic*** list item
- `Inline code` in a list item
- ~~Strikethrough~~ list item
- Item with a [link](https://example.com) in it
- Item with an ![image](https://example.com/img.png)
- Item with <em>HTML inline</em> elements
- Item with footnote reference[^1]
- Item with `multiple` pieces of `inline code`
- Item with **bold `code` inside bold**
- Item with *nested **bold** inside italic*

## 11. Tight vs. Loose Lists

Tight list (no blank lines between items):
- Apple
- Banana
- Cherry
- Date
- Elderberry

Loose list (blank lines between items):

- Apple

- Banana

- Cherry

- Date

- Elderberry

Mixed tight and loose:

- Apple
- Banana

- Cherry
- Date

- Elderberry

## 12. Edge Cases: Empty List Items

-
- Second item after empty
-
- Fourth item after marker-only

1.
2. Second ordered after empty
3.
4. Fourth ordered after marker-only

-
  - Nested item under empty parent
  - Another nested item

## 13. Nested Lists with Varying Indentation

Standard 2-space indent:
- Level 1
  - Level 2
    - Level 3
      - Level 4

Standard 4-space indent:
- Level 1
    - Level 2
        - Level 3
            - Level 4

Tab indent:
- Level 1
	- Level 2
		- Level 3
			- Level 4

Mixed indentation (potential parser confusion):
- Level 1
  - Level 2 (2 spaces)
    - Level 3 (4 spaces total)
        - Level 4 (8 spaces total)
          - Level 5 (10 spaces total)

3-space indent for ordered:
1. Level 1
   1. Level 2
      1. Level 3
         1. Level 4

## 14. Task Lists (GFM Extension)

- [x] Completed task
- [ ] Incomplete task
- [x] Another completed task
  - [x] Nested completed subtask
  - [ ] Nested incomplete subtask
    - [x] Deep nested completed
    - [ ] Deep nested incomplete
      - [x] Very deep completed
      - [ ] Very deep incomplete
- [ ] Task with **formatted** content
- [ ] Task with `code` in it
- [ ] Task with a [link](https://example.com)
- [x] Task followed by paragraph

  This paragraph is part of the completed task item.

## 15. Definition Lists (Extended Syntax)

Term 1
: Definition for term 1. This is a simple definition that spans
  a single conceptual paragraph.

Term 2
: First definition for term 2.
: Second definition for term 2. Some parsers support multiple
  definitions for a single term.

Complex Term
: A definition that contains multiple paragraphs.

  This is the second paragraph of the definition. It needs to be
  indented to be considered part of the definition.

  And a third paragraph for good measure.

Another Term
: Definition with a code block:

  ```javascript
  console.log("Inside a definition");
  ```

: And a second definition.

Nested Term
: Definition containing a list:
  - Sub-item one
  - Sub-item two
  - Sub-item three

## 16. Extremely Long List

- Item 001: Lorem ipsum dolor sit amet, consectetur adipiscing elit
- Item 002: Sed do eiusmod tempor incididunt ut labore et dolore magna
- Item 003: Ut enim ad minim veniam, quis nostrud exercitation ullamco
- Item 004: Duis aute irure dolor in reprehenderit in voluptate velit
- Item 005: Excepteur sint occaecat cupidatat non proident sunt in culpa
- Item 006: Curabitur pretium tincidunt lacus sed auctor erat proin
- Item 007: Mauris blandit aliquet elit eget tincidunt nibh pulvinar
- Item 008: Vestibulum ante ipsum primis in faucibus orci luctus et
- Item 009: Pellentesque habitant morbi tristique senectus et netus
- Item 010: Maecenas sed diam eget risus varius blandit sit amet non
- Item 011: Cras ultricies ligula sed magna dictum porta vestibulum
- Item 012: Vivamus magna justo lacinia eget consectetur sed convallis
- Item 013: Nulla quis lorem ut libero malesuada feugiat proin eget
- Item 014: Praesent sapien massa convallis a pellentesque nec egestas
- Item 015: Donec sollicitudin molestie malesuada nam quis hendrerit
- Item 016: Quisque velit nisi pretium ut lacinia in elementum id enim
- Item 017: Nulla porttitor accumsan tincidunt cras ultricies ligula
- Item 018: Donec rutrum congue leo eget malesuada pellentesque elit
- Item 019: Curabitur non nulla sit amet nisl tempus convallis quis ac
- Item 020: Vestibulum ac diam sit amet quam vehicula elementum sed sit
- Item 021: Proin eget tortor risus vivamus suscipit tortor eget felis
- Item 022: Mauris blandit aliquet elit eget tincidunt nibh pulvinar a
- Item 023: Nulla quis lorem ut libero malesuada feugiat nulla facilisi
- Item 024: Cras ultricies ligula sed magna dictum porta curabitur arcu
- Item 025: Pellentesque in ipsum id orci porta dapibus sed porttitor

## 17. Lists with Footnotes and References

- First item with a footnote[^note1]
- Second item referencing [an external resource][ext-ref]
- Third item with both a footnote[^note2] and a [direct link](https://example.com)
  - Sub-item also with a footnote[^note3]
    - Deep sub-item with [reference link][deep-ref]

[^note1]: This footnote belongs to the first list item.
[^note2]: This footnote belongs to the third list item and contains
    multiple lines that should be indented.
[^note3]: Footnote for the nested sub-item.

[ext-ref]: https://example.com/external "External Resource"
[deep-ref]: https://example.com/deep "Deep Reference"

[^1]: Footnote from section 10.

## 18. Interleaved List Types

- Unordered item A

1. Ordered item A

- Back to unordered B

2. Ordered again starting at 2

- Unordered once more C
  1. Nested ordered inside unordered
     - Nested unordered inside that
       1. And ordered again at depth
  2. Continuing nested ordered
- Final unordered D

## 19. Lists with Horizontal Rules as Separators

- Item before first rule

---

- Item between rules

---

- Item after second rule

---

1. Ordered after rules

## 20. Very Wide List Items

- This is an extremely long list item that goes on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on to test how parsers handle very wide content in a single list item without any line breaks
- Normal item for contrast
- Another extremely long list item that contains `inline code spans` and **bold formatting** and *italic formatting* and [links to websites](https://example.com) and ![image references](https://example.com/img.png) all within a single very very very very very very very very very very very very very very long line

## 21. Lists Containing Only Whitespace Characters

-
- Item after whitespace-only item
-
- Item after tab-and-space item

## 22. Consecutive Lists of Different Types

- Unordered one
- Unordered two

1. Ordered one
2. Ordered two

* Asterisk one
* Asterisk two

+ Plus one
+ Plus two

3. Starting at three
4. Then four

## 23. List Item Containing Another Full Document Structure

- This list item contains a mini-document:

  ## Sub-heading (inside list item)

  A paragraph with **bold** and *italic* text.

  > A blockquote inside the list item.

  ```python
  print("code block inside list item")
  ```

  | Header A | Header B |
  |----------|----------|
  | Cell 1   | Cell 2   |

  Another paragraph to close out the mini-document.

- Normal list item after the complex one.

## 24. Deeply Nested Mixed with Multi-Paragraph at Every Level

- Level 1 content here.

  Level 1 continuation paragraph.

  - Level 2 content here.

    Level 2 continuation paragraph.

    1. Level 3 ordered content.

       Level 3 continuation paragraph.

       - Level 4 unordered content.

         Level 4 continuation paragraph.

         1. Level 5 ordered content.

            Level 5 continuation paragraph.

            - Level 6 unordered content.

              Level 6 continuation paragraph. This is the deepest level
              with multi-paragraph support being tested. The parser must
              carefully track indentation at each level.

            - Another level 6 item.

         2. Another level 5 item.

       - Another level 4 item.

    2. Another level 3 item.

  - Another level 2 item.

- Another level 1 item.
