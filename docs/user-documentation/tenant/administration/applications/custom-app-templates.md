# Custom App Templates

A custom app template holds one custom app package (.zip): the file your developer or vendor supplies for **Upload custom apps** in Integrated apps or the Teams admin center. It contains a manifest.json and the app's two icons. Save it once here and deploy it to as many tenants as you need, instead of uploading it in each tenant's admin center.

Templates work for any custom app package, whether it is a Teams app, an Outlook add-in built as a Microsoft 365 app, or an app that runs in Teams, Outlook and Microsoft 365. Each template holds one app; to roll out a new version, use **Upload New Version** on that app's template.

## Adding a template

1. Select **Add Template**.
2. Optionally enter a template name. It defaults to the app's name from the package.
3. Upload the .zip and select **Submit**.

The package must have manifest.json at the top level of the .zip, not inside a folder. CIPP reads the app's name, ID and version from it.

## Deploying a template

Select **Deploy Template**, or **Deploy to Tenants** on a template. Pick the template and the tenants. Each tenant gets the app added to its app catalog, or updated if it has an older version. A tenant that already has the same or a newer version is left as it is.

Deploying adds the app to the tenant's app catalog. Who can use the app, and whether it is installed or pinned for users automatically, is still set by the tenant's Teams app policies.

To keep tenants on the latest version automatically, add the **Custom App Template** standard to a baseline and select the template. The baseline reports tenants that are missing the app or on an older version, and can add or update it.

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Deploy to Tenants</td><td>Opens the deploy page with this template selected.</td><td>false</td></tr><tr><td>Upload New Version</td><td>Replaces the template's package with a newer version of the same app.</td><td>false</td></tr><tr><td>Delete Template</td><td>Deletes the template after a confirmation prompt. Apps already in tenant app catalogs stay there.</td><td>false</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

Managing and deploying templates needs the Tenant.Application.ReadWrite permission. Deploying also needs the Teams Administrator role in your GDAP relationship with each tenant, and the CIPP app needs the AppCatalog.ReadWrite.All permission, which CIPP's permission check adds after updating.

{% include "../../../../../.gitbook/includes/feature-request.md" %}
