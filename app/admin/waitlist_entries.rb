ActiveAdmin.register WaitlistEntry do
  permit_params :business_link, :email, :phone
end
