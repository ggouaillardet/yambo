!
! Copyright (C) 2000-2010 A. Marini and the YAMBO team 
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
subroutine FREQUENCIES_reset(Xw)
 !
 ! Input
 !-------
 ! integer     :: npts
 ! real(SP)    :: bg_pt(npts),cg_percentual
 !
 ! Deallocate:  
 ! bg_pt(:), cg_pt(:), cg_index_bg(:),
 ! X_poles_tab(:), rg_index_bg(:), bg_npts(:)
 !
 use frequency,   ONLY:w_samp,bg_npts,cg_npts,cg_pt,rg_index_bg,cg_index_bg
 use memory_m   , ONLY:mem_est
 use X_m,         ONLY:X_poles_tab
 implicit none
 !
 type(w_samp)  :: Xw
 !
 if(associated(Xw%p)) deallocate(Xw%p)
 call mem_est("W-p")
 if (allocated(rg_index_bg)) deallocate(rg_index_bg)
 deallocate(X_poles_tab,bg_npts,cg_pt,cg_index_bg)
 call mem_est("X_poles_tab RGi BGn CGp CGi")      
 !
end subroutine