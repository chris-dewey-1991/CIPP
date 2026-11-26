import { useEffect } from 'react'
import { useRouter } from 'next/router'
import { useForm } from 'react-hook-form'
import { Alert, Stack } from '@mui/material'
import { Layout as DashboardLayout } from '../../../../../layouts/index'
import CippFormPage from '../../../../../components/CippFormPages/CippFormPage'
import CippFormComponent from '../../../../../components/CippComponents/CippFormComponent'
import { CippFormTenantSelector } from '../../../../../components/CippComponents/CippFormTenantSelector'
import { ApiGetCall } from '../../../../../api/ApiCall'

const Page = () => {
  const router = useRouter()
  const { template } = router.query

  const formControl = useForm({
    mode: 'onChange',
    defaultValues: { selectedTenants: [], TemplateId: null },
  })

  const templates = ApiGetCall({
    url: '/api/ListCustomAppTemplates',
    queryKey: 'ListCustomAppTemplates',
  })

  useEffect(() => {
    if (!template || !Array.isArray(templates.data)) return
    const match = templates.data.find((item) => item.GUID === template)
    if (match) {
      formControl.setValue(
        'TemplateId',
        {
          label: `${match.TemplateName} (${match.Version})`,
          value: match.GUID,
        },
        { shouldValidate: true }
      )
    }
  }, [template, templates.data, formControl])

  return (
    <CippFormPage
      formControl={formControl}
      title="Deploy Custom App"
      backButtonTitle="Custom App Templates"
      postUrl="/api/ExecDeployCustomApp"
      queryKey={['ListCustomApps*']}
      allowResubmit={true}
      customDataformatter={(values) => ({
        TemplateId: values.TemplateId?.value,
        selectedTenants: values.selectedTenants,
      })}
    >
      <Stack spacing={2}>
        <Alert severity="info">
          Adds the app to each tenant&apos;s Teams and Microsoft 365 app
          catalog, or updates it where the tenant has an older version. Who can
          use or automatically gets the app is set by the tenant&apos;s Teams
          app policies. To keep tenants on the latest version automatically, add
          the Custom App Template standard to a baseline.
        </Alert>
        <CippFormComponent
          type="autoComplete"
          label="Custom app template"
          name="TemplateId"
          multiple={false}
          creatable={false}
          formControl={formControl}
          options={
            Array.isArray(templates.data)
              ? templates.data.map((item) => ({
                  label: `${item.TemplateName} (${item.Version})`,
                  value: item.GUID,
                }))
              : []
          }
          isFetching={templates.isFetching}
          validators={{ required: 'Select a template.' }}
        />
        <CippFormTenantSelector
          label="Tenants"
          formControl={formControl}
          name="selectedTenants"
          type="multiple"
          allTenants={true}
          preselectedEnabled={true}
          validators={{ required: 'Select at least one tenant.' }}
        />
      </Stack>
    </CippFormPage>
  )
}

Page.getLayout = (page) => (
  <DashboardLayout usesTenant={false}>{page}</DashboardLayout>
)

export default Page
