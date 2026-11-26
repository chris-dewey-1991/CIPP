import { Button } from '@mui/material'
import { Stack } from '@mui/system'
import Link from 'next/link'
import { Layout as DashboardLayout } from '../../../../../layouts/index'
import { CippIcons } from '../../../../../utils/icon-registry'
import { TabbedLayout } from '../../../../../layouts/TabbedLayout'
import { CippTablePage } from '../../../../../components/CippComponents/CippTablePage.jsx'
import { usePermissions } from '../../../../../hooks/use-permissions.js'
import tabOptions from '../tabOptions'

const Page = () => {
  const { checkPermissions } = usePermissions()
  const canWriteApplication = checkPermissions(['Tenant.Application.ReadWrite'])

  const actions = canWriteApplication
    ? [
        {
          label: 'Deploy to Tenants',
          icon: <CippIcons.RocketLaunch />,
          pinned: true,
          link: '/tenant/administration/applications/custom-app-templates/deploy?template=[GUID]',
        },
        {
          label: 'Upload New Version',
          icon: <CippIcons.Upload />,
          link: '/tenant/administration/applications/custom-app-templates/add?template=[GUID]&name=[TemplateName]',
        },
        {
          label: 'Delete Template',
          icon: <CippIcons.Delete />,
          color: 'danger',
          type: 'POST',
          url: '/api/ExecCustomAppTemplate',
          data: { Action: '!Delete', TemplateId: 'GUID' },
          confirmText:
            "Delete the template '[TemplateName]'? Apps already in tenant app catalogs stay there. Remove it from any baseline that uses it.",
          multiPost: false,
          relatedQueryKeys: ['ListCustomAppTemplates', 'ListCustomApps*'],
        },
      ]
    : []

  const offCanvas = {
    extendedInfoFields: [
      'TemplateName',
      'AppName',
      'Description',
      'Developer',
      'Version',
      'ManifestId',
      'FileName',
      'CreatedBy',
      'CreatedOn',
      'UpdatedBy',
      'UpdatedOn',
    ],
    actions,
  }

  return (
    <CippTablePage
      title="Custom App Templates"
      apiUrl="/api/ListCustomAppTemplates"
      queryKey="ListCustomAppTemplates"
      tenantInTitle={false}
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={[
        'TemplateName',
        'AppName',
        'Version',
        'Developer',
        'UpdatedBy',
        'UpdatedOn',
      ]}
      cardButton={
        canWriteApplication ? (
          <Stack direction="row" spacing={2}>
            <Button
              component={Link}
              href="/tenant/administration/applications/custom-app-templates/add"
              startIcon={<CippIcons.Add />}
            >
              Add Template
            </Button>
            <Button
              component={Link}
              href="/tenant/administration/applications/custom-app-templates/deploy"
              startIcon={<CippIcons.RocketLaunch />}
            >
              Deploy Template
            </Button>
          </Stack>
        ) : null
      }
    />
  )
}

Page.getLayout = (page) => (
  <DashboardLayout usesTenant={false}>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
)

export default Page
