!
! Copyright (C) 2000-2008 A. Marini and the YAMBO team 
!              http://www.yambo-code.org
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
module electrons
 !
 use pars
 real(SP) :: nel
 real(SP) :: default_nel
 real(SP) :: spin_occ
 real(SP) :: filled_tresh
 integer  :: n_bands
 integer  :: n_met_bands
 integer  :: n_full_bands
 !
 ! Spin support
 !
 !     n_spin n_sp_pol n_spinor  
 !       1        1        1              
 !       2        1        2    non collinear
 !       2        2        1        collinear
 !
 ! Note that in the non collinear case n_spin is an index
 ! for the spinor components. It is not a Physical quantity.
 !
 integer  :: n_spin
 integer  :: n_sp_pol
 integer  :: n_spinor
 logical  :: spin_orbit
 !
 type levels
   integer         :: nb
   integer         :: nk
   integer         :: nbf
   integer         :: nbm
   integer         :: bf
   integer         :: kf
   integer         :: sf
   integer,pointer :: qp_done(:,:)
   real(SP)            :: Efermi(3)
   real(SP),   pointer :: E(:,:,:)
   real(SP),   pointer :: Eo(:,:,:)
   real(SP),   pointer :: f(:,:,:)
   real(SP),   pointer :: W(:,:,:)
   complex(SP),pointer :: Z(:,:,:)
   ! 
   ! Fine energy grid
   !  
   real(SP),   pointer :: E_RIM(:,:,:)
   real(SP),   pointer :: f_RIM(:,:,:)
   !
 end type levels
 ! 
 ! Fine energy grid Tables
 !   
 integer  :: BZ_RIM_max_filling
 integer  :: BZ_RIM_tot_nkpts
 integer  :: BZ_RIM_nbands
 integer ,allocatable :: BZ_RIM_nkpt(:)
 integer ,allocatable :: BZ_RIM_table(:,:)
 !
 contains
   !
   subroutine E_duplicate(Ei,Eo)
     use com,       ONLY:warning
     use memory_m,  ONLY:mem_est
     implicit none
     type(levels):: Ei,Eo
     !
     integer :: qp_done_bounds(2)
     logical :: naive
     !
     naive=Eo%nk==0
     Eo%nb=Ei%nb
     if (naive) then
       Eo%nk=Ei%nk
       Eo%nbf=Ei%nbf
       Eo%nbm=Ei%nbm
       Eo%bf=Ei%bf
       Eo%kf=Ei%kf
       Eo%sf=Ei%sf
       Eo%Efermi=Ei%Efermi
     endif
     allocate(Eo%E(Eo%nb,Eo%nk,n_sp_pol),Eo%f(Eo%nb,Eo%nk,n_sp_pol))
     call mem_est("E-E E-f",(/size(Eo%E),size(Eo%f)/),(/SP,SP/))
     Eo%E=0.
     Eo%f=0.
     if (naive) then
       Eo%f(:,:,:)=Ei%f(:,:,:)
       Eo%E(:,:,:)=Ei%E(:,:,:)
       if (associated(Ei%Eo)) then
         allocate(Eo%Eo(Eo%nb,Eo%nk,n_sp_pol))
         call mem_est("E-Eo",(/size(Eo%E)/),(/SP/))
         Eo%Eo=Ei%Eo
       endif
       if (associated(Ei%W)) then
         allocate(Eo%W(Eo%nb,Eo%nk,n_sp_pol))
         call mem_est("E-W",(/size(Eo%W)/),(/SP/))
         Eo%W=Ei%W
       endif
       if (associated(Ei%Z)) then
         allocate(Eo%Z(Eo%nb,Eo%nk,n_sp_pol))
         call mem_est("E-Z",(/size(Eo%Z)/))
         Eo%Z=Ei%Z
       endif
       if (associated(Ei%qp_done)) then
         qp_done_bounds=shape(Ei%qp_done)
         allocate(Eo%qp_done(qp_done_bounds(1),qp_done_bounds(2)))
         call mem_est("E-qp_done",(/size(Eo%qp_done)/),(/IP/))
         Eo%qp_done=Ei%qp_done
         call warning(' QP corrections transferred in energy levels duplication')
       endif
     else
       Eo%E(:,:,:)=Ei%E(:,:Eo%nk,:)
     endif
     !
     ! E RIM
     !
     if (BZ_RIM_nbands/=0.and.Ei%nk==Eo%nk) then
       allocate(Eo%E_RIM(BZ_RIM_nbands,BZ_RIM_tot_nkpts,n_sp_pol))
       allocate(Eo%f_RIM(BZ_RIM_nbands,BZ_RIM_tot_nkpts,n_sp_pol))
       call mem_est("E_RIM f_RIM",(/size(Eo%E_RIM),size(Eo%f_RIM)/),(/SP,SP/))
       Eo%E_RIM=Ei%E_RIM
       Eo%f_RIM=Ei%f_RIM
     endif
     !
   end subroutine
   !
   subroutine E_reset(E)
     use memory_m, ONLY:mem_est
     implicit none
     type(levels)::E
     E%Efermi=0.
     E%nb=0
     E%nk=0
     E%nbf=0 
     E%nbm=0
     E%bf=0
     E%kf=0 
     nullify(E%E,E%Eo,E%Z,E%W,E%f,E%qp_done)
     call mem_est("E-E E-Eo E-f E-W E-Z E-qp_done")
     !
     nullify(E%E_RIM,E%f_RIM)
     call mem_est("E_RIM f_RIM")
     !
   end subroutine
   !
   integer function spin(v)
     integer :: v(:)
     !
     spin=1
     !
     !
   end function
   !
end module electrons