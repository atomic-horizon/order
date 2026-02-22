---
sidebar_position: 1
title: Introduction
---

# Introduction
Order is a module loader framework for Roblox that provides simple and fast module lookup, cyclic dependency support, a customizable initialization sequence, and more!

## What's so special about Order?
The core design principle in Order is to **remove barriers and enable the developer**. It combines the best features of current popular frameworks, and adds a few of its own.

## Are there any unique features in Order?
 There are! One of these unique features is the ability to have modules with circular dependencies. Occasionally, libaries and tasks need to interchangably use one another's public functions and variables, but Luau doesn't allow this by default. Order achieves support for this through a metatable-based bait-and-switch style tactic (see [Special notes](/order/notes)).

## Is there anything else I need to know?
Order is a relatively new framework, and I'm still actively developing it. As such, functionality and features can and will change at any time and I'm still ironing out all the kinks and bugs. If you have any suggestions or find any bugs yourself, feel free to reach out! Issues, discussions, and pull requests can be submitted to [the project repo](https://github.com/atomic-horizon/order)!
