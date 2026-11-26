import { Button } from '@mui/material'
import Link from 'next/link'
import { Layout as DashboardLayout } from '../../../../layouts/index'
import { CippIcons } from '../../../../utils/icon-registry'
import { TabbedLayout } from '../../../../layouts/TabbedLayout'
import { CippTablePage } from '../../../../components/CippComponents/CippTablePage.jsx'
import { usePermissions } from '../../../../hooks/use-permissions.js'
import { useSettings } from '../../../../hooks/use-settings'
import tabOptions from './tabOptions'

const Page = () => {
  const pageTitle = 'Custom Apps'
  const tenant = useSettings().currentTenant
  const { checkPermissions } = usePermissions()
  const canWriteApplication = checkPermissions(['Tenant.Application.ReadWrite'])
  const queryKey = `ListCustomApps-${tenant}`

  const actions = canWriteApplication
    ? [
        {
          label: 'Update to Template Version',
          type: 'POST',
          url: '/api/ExecDeployCustomApp',
          icon: <CippIcons.Update />,
          customDataformatter: (row) => {
            const toPayload = (app) => ({
              TemplateId: app.templateId,
              selectedTenants: [{ value: tenant }],
            })
            return Array.isArray(row) ? row.map(toPayload) : toPayload(row)
          },
          confirmText:
            "Update '[displayName]' from version [version] to the template's version [templateVersion]?",
          condition: (row) => row.templateStatus === 'Update available',
          multiPost: false,
          relatedQueryKeys: [queryKey],
        },
        {
          label: 'Remove from App Catalog',
          type: 'POST',
          url: '/api/RemoveCustomApp',
          icon: <CippIcons.Delete />,
          color: 'danger',
          data: { ID: 'id', displayName: 'displayName' },
          confirmText:
            "Remove '[displayName]' from this tenant's app catalog? Users lose access to the app in Teams, Outlook and Microsoft 365.",
          multiPost: false,
          relatedQueryKeys: [queryKey],
        },
      ]
    : []

  const offCanvas = {
    extendedInfoFields: [
      'displayName',
      'shortDescription',
      'version',
      'publishingState',
      'externalId',
      'templateName',
      'templateVersion',
      'templateStatus',
      'lastModifiedDateTime',
    ],
    actions,
  }

  const filters = [
    {
      filterName: 'Update available',
      value: [{ id: 'templateStatus', value: 'Update available' }],
      type: 'column',
    },
    {
      filterName: 'No template',
      value: [{ id: 'templateStatus', value: 'No template' }],
      type: 'column',
    },
  ]

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListCustomApps"
      queryKey={queryKey}
      actions={actions}
      offCanvas={offCanvas}
      filters={filters}
      simpleColumns={[
        'displayName',
        'version',
        'publishingState',
        'templateName',
        'templateStatus',
        'lastModifiedDateTime',
      ]}
      cardButton={
        <Button
          component={Link}
          href="/tenant/administration/applications/custom-app-templates"
          startIcon={<CippIcons.Upload />}
        >
          Custom App Templates
        </Button>
      }
    />
  )
}

Page.getLayout = (page) => (
  <DashboardLayout allTenantsSupport={false}>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
)

export default Page
