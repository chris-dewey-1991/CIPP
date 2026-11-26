# Custom Apps

Custom apps are your organisation's own Teams and Microsoft 365 apps, such as a client portal or a line-of-business tool, uploaded as an app package (.zip) rather than installed from the Microsoft store. This page lists the custom apps in the selected tenant's app catalog: the same apps you see under **Upload custom apps** in Integrated apps or in the Teams admin center. It needs a single tenant selected.

To put the same app in many tenants, or to roll out a new version, save the package as a [custom app template](custom-app-templates.md) and deploy it from there.

## Filters

| Filter           | Shows                                                                          |
| ---------------- | ------------------------------------------------------------------------------ |
| Update available | Apps a custom app template holds a newer version of.                           |
| No template      | Apps with no custom app template, for example ones uploaded outside of CIPP.   |

## Table Details

| Column          | Description                                                                                       |
| --------------- | ------------------------------------------------------------------------------------------------- |
| Display Name    | The app's name.                                                                                   |
| Version         | The newest version of the app in the tenant's catalog.                                            |
| Publishing State | Published, or Submitted when a user has sent the app for admin approval.                         |
| Template Name   | The custom app template that holds this app, if there is one.                                     |
| Template Status | Up to date, Update available, Newer than template, or No template.                                |
| Last Modified   | When the current version was uploaded.                                                            |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Update to Template Version</td><td>Uploads the template's version of the app. Shown when the template holds a newer version.</td><td>true</td></tr><tr><td>Remove from App Catalog</td><td>Removes the app from the tenant's app catalog after a confirmation prompt. Users lose access to it.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

Updating and removing apps need the Tenant.Application.ReadWrite permission. Viewing the list needs Tenant.Application.Read. Changing a tenant's app catalog also needs the Teams Administrator role in your GDAP relationship with the tenant.

{% include "../../../../../.gitbook/includes/feature-request.md" %}
