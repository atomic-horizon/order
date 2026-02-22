---
sidebar_position: 4
title: Special Notes
---

# Special Notes
## No bare code in modules with cyclic dependencies
In order to support cyclic dependencies, it must be guaranteed that the module in question has **no bare code that references a cyclic dependency**. That is to say that any code that references the cyclic dependency must be contained within a function. If Order detects this bare code, you will be notified with a warning in the output and no operation will be processed on the module in question.

## Loading modules with non-unique names
Modules can be specified through several different paths. If the name is unique, you can reference it simply through that. If two modules exist with the same name however, Order will warn you that it found two or more possible modules for your request, and will ask you to be more specific. You can use any level of the module paths it provides you with, as long as they're unique as well.

Order does not index all potential file paths by default, so it is recommended to use the **shortest unique paths possible** in order to conserve memory usage.

## Printing module tables
One of the complications with the method Order uses to support cyclic dependencies is that if you try to print out one of these module's tables, it would return a table address instead of an output-friendly table. In order to preserve as much functionality as possible, Order will list out table keys and values in a custom format when converting the table to a string.
