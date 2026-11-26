import { useEffect } from 'react'
import { useRouter } from 'next/router'
import { useForm } from 'react-hook-form'
import { Alert, Stack } from '@mui/material'
import { Layout as DashboardLayout } from '../../../../../layouts/index'
import CippFormPage from '../../../../../components/CippFormPages/CippFormPage'
import CippFormComponent from '../../../../../components/CippComponents/CippFormComponent'

const Page = () => {
  const router = useRouter()
  const { template, name } = router.query
  const isNewVersion = Boolean(template)

  const formControl = useForm({
    mode: 'onChange',
    defaultValues: {
      TemplateName: '',
      PackageFile: null,
      Package: '',
      FileName: '',
    },
  })

  useEffect(() => {
    formControl.register('Package', {
      required: 'Upload the app package (.zip).',
    })
    formControl.register('FileName')
  }, [formControl])

  useEffect(() => {
    if (name) formControl.setValue('TemplateName', name)
  }, [name, formControl])

  const readPackage = (file) => {
    if (!file) {
      formControl.setValue('Package', '', { shouldValidate: true })
      return
    }
    const reader = new FileReader()
    reader.onload = () => {
      formControl.setValue('Package', reader.result, { shouldValidate: true })
      formControl.setValue('FileName', file.name)
    }
    reader.readAsDataURL(file)
  }

  return (
    <CippFormPage
      formControl={formControl}
      title={
        isNewVersion
          ? `Upload New Version - ${name ?? 'Custom App Template'}`
          : 'Custom App Template'
      }
      backButtonTitle="Custom App Templates"
      postUrl="/api/ExecCustomAppTemplate"
      queryKey={['ListCustomAppTemplates', 'ListCustomApps*']}
      customDataformatter={(values) => ({
        Action: 'Save',
        TemplateId: template,
        TemplateName: values.TemplateName,
        Package: values.Package,
        FileName: values.FileName,
      })}
    >
      <Stack spacing={2}>
        <Alert severity="info">
          Upload the app package your developer or vendor supplied: a .zip
          containing manifest.json and the app&apos;s two icons. This is the
          same file you would upload under Integrated apps or in the Teams admin
          center.
          {isNewVersion &&
            ' The new package must be the same app with a higher version number. Tenants on an older version are updated when you deploy the template or when a baseline using it runs.'}
        </Alert>
        <CippFormComponent
          type="textField"
          label="Template name (optional, defaults to the app's name)"
          name="TemplateName"
          formControl={formControl}
        />
        <CippFormComponent
          type="file"
          label="App package (.zip)"
          name="PackageFile"
          accept=".zip,application/zip"
          formControl={formControl}
          onChange={readPackage}
          validators={{
            required: 'Upload the app package (.zip).',
            validate: (file) =>
              !file ||
              file.name?.toLowerCase().endsWith('.zip') ||
              'The app package must be a .zip file.',
          }}
        />
      </Stack>
    </CippFormPage>
  )
}

Page.getLayout = (page) => (
  <DashboardLayout usesTenant={false}>{page}</DashboardLayout>
)

export default Page
