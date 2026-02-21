![banner](https://user-images.githubusercontent.com/67706277/210158331-c96900fc-d645-4893-a95c-fd4eb700a975.png)

# Getting Started
The following instructions will get you up and running with an Order-powered experience! This assumes that you have at least a basic understanding of Roblox Studio.

## 1) Download VS Code and Rojo
1. Download and install VS Code from [here](https://code.visualstudio.com/)
2. From VS Code, install the extension Rojo from the Extensions tab on the left sidebar or through [this link.](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo)
3. In Roblox Studio, search for and add the plugin for Rojo through the toolbox, or use [this link.](https://create.roblox.com/marketplace/asset/6415005344/Rojo-7)

## 2) Create a new repository based on this template
1. At the top of this page, click the green "Use this template" button and select "Create a new repository"
2. Select the proper owner, add a name, choose your desired visiblity options, and click "Create repository from template"
3. Using the software of your choice (I typically use VS Code's Source Control menu), clone your new repository to your computer

## 3) Initialize Wally
1. If you don't yet have Wally, you can install it [from here.](https://github.com/UpliftGames/wally)
2. Open a terminal in your new project's directory and run the command `wally install` to get the included packages.

## 4) Project configuration
1. Open the new repository in VS Code and then open the `default.project.json` file
2. At the top, you'll see a string that reads "New Order Project", replace this with the name of your new project and save the file

## 5) Sync code into Roblox Studio
1. In VS Code, click the Rojo button on the bottom right (if you don't see this icon, verify the Rojo extension is installed and restart VS Code)
2. In the context menu that appears, click on `default.project.json` at the bottom
3. In Roblox Studio, create or open a place file that will host your new experience
4. Switch to the Plugins tab, and select Rojo
5. In the Rojo window that appears, click "Connect"

You are now up and running with Order! Any code you write in VS Code will be synced into your new game whenever you save the file. If you need further help, you can visit [the DevForum](https://devforum.roblox.com/), read [the Order docs](https://michaeldougal.github.io/order/), or check out [the Rojo docs](https://rojo.space/)!
